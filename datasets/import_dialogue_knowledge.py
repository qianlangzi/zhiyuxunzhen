# -*- coding: utf-8 -*-
"""
向量库扩充脚本：把清洗后的医患问答语料嵌入并写入 zhiyu_textbook 集合（Milvus）。

数据源：Chinese-medical-dialogue-data（6 科室，79 万条真实医患问答）
定位：作为问诊/咨询检索参考语料，补充教材向量库之外的真实问答知识。

【质量与规范（垂类要求）】
1. 负向过滤：剔除广告/绝对化/承诺治愈/保健品/偏方等营销话术（防止污染检索）
2. 正向要求：answer 必须包含规范诊疗表述（建议/诊断/检查/用药/随访/注意事项等），
             且长度足够，保证是"可作参考的问答"而非纯口语/免责
3. 规范化：subject=科室、chapter=疾病词、chunk_text 结构化(主诉/医生建议)、
           book_name/edition 标注来源性质，便于追溯
4. 保守规模：health 优先，宁少而精；支持 --limit 与 --dry-run 先人工抽检

嵌入：DashScope qwen3-vl-embedding（1024 维），标准库并发
写入：pymilvus upsert 到 zhiyu_textbook（生产集合，字段与现有规范一致）

依赖：pip install pymysql pymilvus
运行：
  python import_dialogue_knowledge.py --dry-run   # 仅统计+抽样，不调嵌入
  python import_dialogue_knowledge.py --limit 2000  # 嵌入并入库（默认写全部）
"""
import argparse
import csv
import hashlib
import io
import json
import os
import random
import sys
import urllib.request

DASHSCOPE_API_KEY = os.getenv("DASHSCOPE_API_KEY", "")
DASHSCOPE_BASE = os.getenv("DASHSCOPE_BASE_URL", "")
EMBED_MODEL = os.getenv("DASHSCOPE_EMBEDDING_MODEL", "qwen3-vl-embedding")
EMBED_DIM = int(os.getenv("DASHSCOPE_EMBEDDING_DIM", "1024"))
EMBED_ENDPOINT = f"{DASHSCOPE_BASE}/services/embeddings/multimodal-embedding/multimodal-embedding"

MILVUS_URI = os.getenv("MILVUS_URI", "http://127.0.0.1:19531")
MILVUS_COLLECTION = os.getenv("MILVUS_COLLECTION", "zhiyu_textbook")

RAW_ROOT = os.getenv("DIALOGUE_ROOT", r"e:\zhiyu\datasets\raw\Chinese-medical-dialogue-data")
CACHE_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".dialogue_emb_cache.json")

# 数据科室 -> 院内科室（与 import_dialogue_cases.py 一致）
DEPT_MAP = {
    "心血管科": "心血管内科", "神经科": "神经内科", "消化科": "消化内科",
    "妇科": "妇产科", "儿科": "儿科", "骨科": "骨科", "男科": "男科", "内科": "综合",
}
KNOWN_DEPT = set(DEPT_MAP) | {"呼吸科", "内分泌科", "肾内科", "皮肤科", "泌尿科", "肿瘤科", "外科", "感染科"}

# 疾病词库（匹配 title+ask，作为 chapter 与疾病标签）
DISEASE_TERMS = [
    "高血压", "低血压", "冠心病", "心肌梗死", "心律失常", "心力衰竭", "心绞痛", "高脂血症", "高血脂",
    "糖尿病", "甲状腺功能亢进", "甲状腺功能减退", "甲状腺结节", "甲亢", "痛风",
    "肺炎", "哮喘", "慢阻肺", "慢性阻塞性肺疾病", "支气管炎", "肺结核", "肺癌", "肺结节", "咳嗽",
    "胃炎", "胃溃疡", "胃癌", "十二指肠溃疡", "消化不良", "腹泻", "便秘", "胰腺炎", "脂肪肝",
    "肝炎", "肝硬化", "乙肝", "胆囊炎", "胆结石", "痔疮", "肠炎", "肠息肉", "阑尾炎",
    "脑梗死", "脑出血", "脑梗", "脑血栓", "癫痫", "帕金森", "偏头痛", "头痛", "眩晕", "面瘫",
    "肾炎", "肾病综合征", "尿毒症", "肾结石", "尿路感染", "前列腺炎", "前列腺增生",
    "贫血", "白血病", "淋巴瘤", "血小板减少",
    "类风湿关节炎", "风湿", "红斑狼疮", "强直性脊柱炎", "骨质疏松",
    "甲状腺癌", "肝癌", "结肠癌", "乳腺癌", "卵巢癌", "子宫肌瘤", "宫颈癌", "鼻咽癌",
    "流感", "感冒", "带状疱疹", "荨麻疹", "湿疹", "银屑病", "发热",
    "焦虑", "失眠", "神经衰弱",
    "骨折", "关节炎", "颈椎病", "腰椎间盘突出", "肩周炎",
    "妊娠", "流产", "宫外孕", "产后", "月经不调", "痛经", "阴道炎", "盆腔炎",
    "多动症", "手足口病", "黄疸",
]

# 广告/营销/绝对化/承诺治愈/不严谨话术（出现即剔除）
NEGATIVE_TERMS = [
    "根治", "包治", "特效", "除根", "彻底治愈", "断根", "神效", "奇效", "药到病除",
    "偏方", "秘方", "祖传", "保健品", "神药", "无副作用", "百分百", "立竿见影", "神奇",
    "加微信", "私人医生", "淘宝", "京东", "代购", "优惠", "促销", "购买链接", "推荐产品",
    "治愈率100%", "保证治愈", "一天见效", "永不复发", "纯中药无副作用",
]

# 规范诊疗表述（answer 必须命中至少一个，保证是可参考的问答）
POSITIVE_TERMS = [
    "及时就医", "建议", "诊断", "检查", "治疗", "用药", "服药", "药物", "剂量",
    "随访", "复查", "观察", "注意", "禁忌", "并发症", "明确诊断", "前往医院",
    "三甲", "医生", "就诊", "预防", "生活方式", "饮食", "监测",
]


def get_csv_files():
    found = []
    for root, _, files in os.walk(RAW_ROOT):
        for f in files:
            if f.endswith(".csv"):
                found.append(os.path.join(root, f))
    return found


def read_dialogue(path):
    try:
        raw = open(path, "rb").read().decode("gbk", errors="replace")
    except OSError:
        return []
    rd = csv.reader(io.StringIO(raw))
    rows = []
    try:
        header = next(rd)
        idx = {c: i for i, c in enumerate(header)}
        if not {"department", "title", "ask", "answer"} <= set(idx):
            return []
    except StopIteration:
        return []
    for line in rd:
        if len(line) < len(header):
            continue
        rows.append({
            "department": (line[idx["department"]] or "").strip(),
            "title": (line[idx["title"]] or "").strip(),
            "ask": (line[idx["ask"]] or "").strip(),
            "answer": (line[idx["answer"]] or "").strip(),
        })
    return rows


def clean_dept(raw_dept):
    return DEPT_MAP.get(raw_dept, raw_dept if raw_dept in KNOWN_DEPT else "")


def extract_disease(title, ask):
    text = f"{title} {ask}"
    for term in DISEASE_TERMS:
        if term in text:
            return term
    return ""


def quality_score(answer):
    """计算 answer 的规范诊疗程度（命中规范词越多分越高）。"""
    hits = sum(1 for t in POSITIVE_TERMS if t in answer)
    return hits


def is_polluted(text_lower):
    """是否含营销/绝对化/不严谨话术。"""
    return any(term in text_lower for term in NEGATIVE_TERMS)


def prepare_records(limit=None):
    """清洗并打分医患问答，返回 [(dept, disease, ask, answer, score)]。"""
    scored: list[tuple[str, str, str, str, float]] = []
    for path in get_csv_files():
        for rec in read_dialogue(path):
            dep = clean_dept(rec["department"])
            if not dep:
                continue
            ask, answer, title = rec["ask"], rec["answer"], rec["title"]
            if len(ask) < 12 or len(answer) < 40 or len(title) < 5:
                continue
            low = f"{ask} {answer}".lower()
            if is_polluted(low):
                continue
            disease = extract_disease(title, ask)
            if not disease:
                continue
            score = quality_score(answer)
            if score < 2:  # 至少命中 2 个规范词
                continue
            scored.append((dep, disease, ask, answer, float(score)))
    print(f"[clean] 通过严格清洗的问答 {len(scored)} 条")

    # 去重（按疾病+主诉首段）
    seen = set()
    dedup = []
    for item in scored:
        dep, disease, ask, answer, sc = item
        key = (disease, ask[:30])
        if key in seen:
            continue
        seen.add(key)
        dedup.append(item)
    print(f"[clean] 去重后 {len(dedup)} 条")

    # 每疾病按质量分排序取 top（防低质灌满，保均衡）
    by_disease: dict[str, list] = {}
    for item in dedup:
        by_disease.setdefault(item[1], []).append(item)
    per_disease_cap = 20
    selected = []
    for disease, items in by_disease.items():
        items.sort(key=lambda x: (-x[4], len(x[3])))
        selected.extend(items[:per_disease_cap])
    random.Random(42).shuffle(selected)

    if limit:
        selected = selected[:limit]
    print(f"[clean] 最终入选 {len(selected)} 条")
    return selected


def chunk_text(disease, ask, answer):
    text = f"【{disease}】主诉：{ask}\n医生建议：{answer}"
    # Milvus varchar 字段 chunk_text 上限 4000（按 UTF-8 字节计）。
    # 中文在 UTF-8 下占 3 字节，3840 字节 ≈ 1280 个汉字，安全性高。
    max_bytes = 3840
    if len(text.encode("utf-8")) <= max_bytes:
        return text
    # 按字节安全截断，避免切断多字节字符
    b = text.encode("utf-8")[:max_bytes]
    while True:
        try:
            return b.decode("utf-8")
        except UnicodeDecodeError:
            b = b[:-1]


def embed_one(text, retries=3):
    payload = {
        "model": EMBED_MODEL,
        "input": {"contents": [{"text": text}]},
        "parameters": {"enable_fusion": True, "dimension": EMBED_DIM},
    }
    req = urllib.request.Request(
        EMBED_ENDPOINT,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Authorization": f"Bearer {DASHSCOPE_API_KEY}",
                 "Content-Type": "application/json"},
        method="POST",
    )
    import time
    last = None
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                data = json.loads(resp.read().decode("utf-8"))
            return data["output"]["embeddings"][0]["embedding"]
        except Exception as e:
            last = e
            if attempt < retries - 1:
                time.sleep(2 ** (attempt + 1))
    raise RuntimeError(f"embed fail: {last}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="仅统计+抽样，不调用嵌入/不写入")
    ap.add_argument("--limit", type=int, default=0, help="最多写入条数（0=全部）")
    args = ap.parse_args()

    recs = prepare_records(args.limit)
    if not recs:
        print("[完成] 无候选")
        return

    if args.dry_run:
        print("\n=== 抽样 8 条（确认质量）===")
        for dep, disease, ask, answer, sc in recs[:8]:
            print(f"\n• [{dep}/{disease}]")
            print(f"  主诉: {ask[:70]}")
            print(f"  建议: {answer[:90]}")
        out = ",".join(f"{d}:{k}" for d, k, *_ in recs)  # noqa
        print(f"\n[dry] 覆盖疾病数: {len({d for _, d, *_ in recs})}")
        return

    from pymilvus import MilvusClient
    cli = MilvusClient(uri=MILVUS_URI)

    # 预查询现有 id，避免主键冲突
    existing = {row["id"] for row in cli.query(MILVUS_COLLECTION, filter="", output_fields=["id"], limit=1)} if False else set()
    try:
        all_ids = []
        offset = 0
        while True:
            rows = cli.query(MILVUS_COLLECTION, filter="book_name == \"医患问答知识库(咨询参考)\"", output_fields=["id"], limit=16384, offset=offset)
            if not rows:
                break
            all_ids.extend(row["id"] for row in rows)
            offset += len(rows)
            if len(all_ids) >= 1_000_000:
                break
        existing = set(all_ids)
    except Exception as e:
        print(f"[warn] 查询已有来源 id 失败({e})，按全量处理")
        existing = set()

    records = []
    seq = 0
    for dep, disease, ask, answer, sc in recs:
        seq += 1
        rid = f"db_{seq}"
        # 确定性去重写入：同一内容只写一次
        h = hashlib.md5(chunk_text(disease, ask, answer).encode("utf-8")).hexdigest()[:16]
        rid = f"db_{h}"
        if rid in existing:
            continue
        records.append({
            "id": rid,
            "book_name": "医患问答知识库(咨询参考)",
            "edition": "v1",
            "chapter": disease,
            "page_number": 0,
            "chunk_text": chunk_text(disease, ask, answer),
            "subject": dep,
            "part": "医患问答",
            "section": disease,
        })

    total = len(records)
    print(f"[embed] 待嵌入 {total} 条")
    if not total:
        print("[完成] 无新增，退出")
        return

    # 加载嵌入缓存（chunk_hash -> 向量），命中的直接复用，避免重复调 API
    cache = {}
    if os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, "r", encoding="utf-8") as f:
                cache = json.load(f)
            print(f"[cache] 载入 {len(cache)} 条嵌入缓存")
        except Exception as e:
            print(f"[warn] 缓存读取失败({e})，忽略")

    # 并发嵌入（分块，失败条跳过并记录；命中缓存直接复用）
    from concurrent.futures import ThreadPoolExecutor, as_completed
    results = {}
    need_embed = []

    def compute_id(i):
        return "db_" + hashlib.md5(records[i]["chunk_text"].encode("utf-8")).hexdigest()[:16]

    for i in range(total):
        rid = compute_id(i)
        if rid in cache:
            results[i] = cache[rid]
        else:
            need_embed.append(i)

    if need_embed:
        with ThreadPoolExecutor(max_workers=6) as ex:
            futs = {ex.submit(embed_one, records[i]["chunk_text"]): i for i in need_embed}
            done = fail = 0
            for fut in as_completed(futs):
                i = futs[fut]
                try:
                    results[i] = fut.result()
                    done += 1
                except Exception:
                    fail += 1
                if (done + fail) % 200 == 0:
                    print(f"  ...嵌入完成 {done + fail}/{len(need_embed)} (失败 {fail})")
        print(f"[embed] 新增嵌入成功 {done}，失败 {fail}（另复用缓存 {total - len(need_embed)} 条）")

        # 回写缓存
        try:
            for i in need_embed:
                if i in results:
                    cache[compute_id(i)] = results[i]
            with open(CACHE_FILE, "w", encoding="utf-8") as f:
                json.dump(cache, f)
            print(f"[cache] 已更新缓存至 {len(cache)} 条")
        except Exception as e:
            print(f"[warn] 缓存回写失败({e})，不影响本次写入")
    else:
        print(f"[embed] 全部命中缓存（{total} 条）")

    upsert_rows = []
    embed_fail = 0
    for i in range(total):
        if i not in results:
            embed_fail += 1
            continue
        r = dict(records[i])
        r["vector"] = results[i]
        upsert_rows.append(r)
    if not upsert_rows:
        print("[完成] 全部嵌入失败，无写入")
        return

    # 分批 upsert（对齐 Milvus 批量）
    batch = 50
    written = 0
    for start in range(0, len(upsert_rows), batch):
        chunk = upsert_rows[start:start + batch]
        for row in chunk:
            row["id"] = row["id"]  # noqa
        cli.upsert(collection_name=MILVUS_COLLECTION, data=chunk)
        written += len(chunk)
        print(f"  ...写入 {written}/{len(upsert_rows)}")
    print(f"[完成] 向量库新增 {written} 条（嵌入失败 {embed_fail}）")


if __name__ == "__main__":
    main()