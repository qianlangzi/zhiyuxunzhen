# -*- coding: utf-8 -*-
"""
向量库扩充脚本：把 OpenCMKG 开源中文医学知识图谱三元组清洗、规范化成 chunk 后
嵌入并写入 zhiyu_textbook 集合（Milvus）。

数据源：OpenCMKG (QAKG + OwnThink + CHIP2021 聚合)，triples.txt 共 35.5 万三元组。
定位：补充教材/问答之外的结构化医学知识（疾病-症状-检查-用药-治疗-科室-并发症-饮食）。

【质量与规范（垂类硬要求）】
1. 仅采纳疾病维度的诊断/治疗相关关系（症状/检查/药物/治疗/科室/并发症/饮食）
2. 实体白名单 + 逐类长度/字符范式过滤（症状短、药物短、检查/治疗可稍长）
3. 按 [,，、;/] 拆分多值实体并单独清洗、去重，隔离噪声
4. entity1 必须是"规范疾病词"（2-14 中文字符、无标点/数字/英文/空白）
5. 绝对黑名单剔除：nan/None/含"测试"等占位或残次词
6. 每个疾病聚合为结构化 chunk，超长按症状分批切块，控制单条 <=3800 字节
7. 支持 --dry-run 先人工抽检、--limit 控制试点规模

嵌入：DashScope qwen3-vl-embedding（1024 维）+ 本地缓存复用
写入：pymilvus upsert 到 zhiyu_textbook（生产集合，字段与现有规范一致）

依赖：pip install pymilvus  （解析为纯标准库 ast/正则，无第三方依赖）
运行：
  python import_opencmkg_knowledge.py --dry-run              # 统计+抽样，不调嵌入
  python import_opencmkg_knowledge.py --dry-run --limit 60   # 只抽 60 个疾病
  python import_opencmkg_knowledge.py --limit 300            # 试点嵌入并入库
"""
import argparse
import ast
import hashlib
import json
import os
import re
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

RAW_ROOT = os.getenv("OPENCMKG_ROOT", r"e:\zhiyu\datasets\raw\OpenCMKG")
TRIPLES = os.path.join(RAW_ROOT, "triples.txt")
ENTITIES = os.path.join(RAW_ROOT, "entities_dict.txt")
CACHE_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".opencmkg_emb_cache.json")

BOOK_NAME = "中文医学知识图谱(OpenCMKG)"
PART = "知识图谱"

# 采纳的关系 -> 中文章节标签
RELS = {
    "disease_has_symptom": "常见症状",
    "disease_need_check": "可能需要检查",
    "disease_recommand_drug": "推荐药物",
    "disease_common_drug": "常用药物",
    "disease_need_treatment": "常用治疗方式",
    "disease_belong_department": "所属科室",
    "disease_acompany_disease": "可能并发",
    "disease_recommand_food": "推荐食物",
    "disease_noteat_food": "忌口食物",
    "disease_eat_food": "可吃食物",
}
DRUG_RELS = {"disease_recommand_drug", "disease_common_drug"}
FOOD_RELS = {"disease_recommand_food", "disease_noteat_food", "disease_eat_food"}

# 每类值长度/字符约束：(min, max, 是否允许含标点/逗号)
# 标点指中文引号括号等；逗号(中英文)统一先作多值分隔拆分，不进入值本身
CAT_RULES = {
    "symptom":    (2, 20, False),
    "check":      (2, 60, True),
    "drug":       (2, 30, False),
    "treatment":  (2, 120, True),
    "department": (2, 20, False),
    "complication": (2, 14, False),
    "food":       (2, 20, False),
}

# 残次/占位词（命中即剔除；不含规范医学术语）
BAN_TERMS = ["测试", "占位", "待定", "填空题", "nan", "none", "NAN", "None"]
# 值内不允许出现的硬字符（标点/数字/英文/空白/手术符号等残次）
BAD_CHARS = re.compile(r"[0-9A-Za-z，,、；;.。!！?？:：()（）\[\]【】<>《》\"'、/\\\s]")


def is_chinese(s):
    return bool(re.search(r"[\u4e00-\u9fa5]", s))


def load_entities():
    """解析 entities_dict.txt（单引号 py 字典，含裸 nan），返回 {类别:[实体]}。"""
    raw = open(ENTITIES, encoding="utf-8").read()
    for attempt in (0, 1):
        try:
            return eval(raw, {"__builtins__": {}})  # 单引号字典，比 json 更宽容
        except NameError:
            # 把裸 nan/None/True/False 引号化后重试
            raw = re.sub(r"\bnan\b", "'nan'", raw)
            raw = re.sub(r"\bNone\b", "\u2018None\u2019"[:0] + "\"'None'\"", raw)
    raise SystemExit("[解析失败] entities_dict.txt 无法解析")


def load_triples():
    """读取 triples.txt（实体1,关系,实体2），返回 [(e1, rel, e2)]。"""
    rows = []
    seen = set()
    with open(TRIPLES, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split(",")
            if len(parts) < 3:
                continue
            e1, rel = parts[0].strip(), parts[1].strip()
            e2 = ",".join(parts[2:]).strip()
            if not (e1 and rel and e2):
                continue
            if rel not in RELS:
                continue
            key = (e1, rel, e2)
            if key in seen:
                continue
            seen.add(key)
            rows.append((e1, rel, e2))
    return rows


def split_multi(value):
    """按中英文逗号/顿号/分号拆成多值片段，忽略空段。"""
    return [t.strip() for t in re.split(r"[,，、;；/]", value) if t.strip()]


def is_valid_disease(s):
    if not s:
        return False
    if not is_chinese(s):
        return False
    if not (1 <= len(s) <= 14) and not (isinstance(s, str) and 2 <= len(s) <= 16):
        pass
    if not (2 <= len(s) <= 16):
        return False
    if re.search(r"[0-9A-Za-z,，、;；/()（）\s]", s):
        return False
    return True


def valid_value(rel, token):
    if not token or any(b in token for b in BAN_TERMS):
        return False
    if not is_chinese(token):
        return False
    # 半角引号往往是残缺值/句段截断残留（如"肝、CT检查），直接剔除
    if '"' in token or "'" in token:
        return False
    rule = None
    if rel in DRUG_RELS:
        rule = CAT_RULES["drug"]
    elif rel in FOOD_RELS:
        rule = CAT_RULES["food"]
    elif rel in ("disease_has_symptom",):
        rule = CAT_RULES["symptom"]
    elif rel == "disease_need_check":
        rule = CAT_RULES["check"]
    elif rel == "disease_need_treatment":
        rule = CAT_RULES["treatment"]
    elif rel == "disease_belong_department":
        rule = CAT_RULES["department"]
    elif rel == "disease_acompany_disease":
        rule = CAT_RULES["complication"]
    else:
        return False
    lo, hi, allow_punct = rule
    if lo <= len(token) <= hi:
        if allow_punct:
            return True
        if not BAD_CHARS.search(token):
            return True
    return False


def collect(rows):
    """按疾病聚合清洗后的 (章节标签 -> 值集合)，并维护疾病->科室映射。"""
    buckets = {}
    dept_of = {}
    for e1, rel, e2 in rows:
        if not is_valid_disease(e1):
            continue
        label = RELS[rel]
        itemset = buckets.setdefault(e1, {}).setdefault(label, set())
        for token in split_multi(e2):
            if not valid_value(rel, token):
                continue
            itemset.add(token)
            if rel == "disease_belong_department":
                dept_of[e1] = token
    return buckets, dept_of


def build_chunks(disease, buckets, max_bytes=3600):
    """把某疾病的各章节聚合为 chunk 文本列表（超长时按症状分批）。"""
    caps = {"常见症状": 70, "可能需要检查": 25, "推荐药物": 35, "常用药物": 35,
            "常用治疗方式": 25, "可吃食物": 25, "推荐食物": 25, "忌口食物": 25,
            "可能并发": 20, "所属科室": 3}
    def section_lines(labels):
        lines = []
        for lab in labels:
            items = cap_items(buckets.get(lab, set()), caps.get(lab, 20))
            if items:
                lines.append(f"{lab}：{'、'.join(items)}")
        return lines

    def cap_items(items, n):
        return list(sorted(items))[:n]

    symptoms = cap_items(buckets.get("常见症状", set()), caps["常见症状"])
    base_labels = ["所属科室", "可能需要检查", "推荐药物", "常用药物",
                   "常用治疗方式", "可吃食物", "推荐食物", "忌口食物", "可能并发"]
    chunks = []
    # 第一批：全部章节 + 症状前 70 个
    first_lines = section_lines(base_labels)
    if symptoms:
        first_lines.insert(0, f"常见症状：{'、'.join(symptoms)}")
    block = "\n".join(first_lines)
    chunks.append(f"【{disease}】{block}")
    # 症状超长时，后续批次只带症状续段
    for start in range(caps["常见症状"], len(symptoms), caps["常见症状"]):
        chunk = symptoms[start:start + caps["常见症状"]]
        chunks.append(f"【{disease}】常见症状（续）：{'、'.join(chunk)}")
    # 逐块按字节安全截断
    return [truncate_bytes(c, max_bytes) for c in chunks]


def truncate_bytes(text, max_bytes):
    b = text.encode("utf-8")
    if len(b) <= max_bytes:
        return text
    b = b[:max_bytes]
    while True:
        try:
            return b.decode("utf-8")
        except UnicodeDecodeError:
            b = b[:-1]


def prepare(limit=0):
    print("[load] 解析实体字典 ...")
    try:
        ents = load_entities()
        print(f"[load] 实体类别: {list(ents.keys())}")
    except Exception as e:
        print(f"[warn] 实体字典解析失败({e})，将仅依赖逐值范式过滤")
        ents = {}
    print("[load] 读取三元组 ...")
    rows = load_triples()
    print(f"[load] 采用关系三元组 {len(rows)} 条")
    buckets, dept_of = collect(rows)
    print(f"[clean] 清洗后有效疾病 {len(buckets)} 个")
    chunks = []
    ordered = list(buckets.keys())
    random.Random(7).shuffle(ordered)
    plan = ordered if limit <= 0 else ordered[:limit]
    for disease in plan:
        for ct in build_chunks(disease, buckets[disease]):
            chunks.append((disease, dept_of.get(disease, ""), ct))
    print(f"[clean] 生成候选 chunk {len(chunks)} 条")
    return chunks


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
    ap.add_argument("--limit", type=int, default=0, help="最多处理疾病数（0=全部）")
    args = ap.parse_args()

    chunks = prepare(args.limit)
    if not chunks:
        print("[完成] 无候选")
        return

    if args.dry_run:
        print("\n=== 抽样 6 条（确认实体质量）===")
        for disease, dept, text in random.Random(1).sample(chunks, min(6, len(chunks))):
            print(f"\n• [{disease}  ({dept or '综合'})]")
            print(f"  {text[:160]}")
        # 去重检查
        diseases = {d for d, _, _ in chunks}
        print(f"\n[dry] 覆盖疾病数 {len(diseases)}，共 {len(chunks)} 条 chunk，平均 {sum(len(t) for _, _, t in chunks)/max(1,len(chunks)):.0f} 字/条")
        return

    from pymilvus import MilvusClient
    cli = MilvusClient(uri=MILVUS_URI)

    existing = set()
    try:
        offset = 0
        page = 16384
        while True:
            rows = cli.query(MILVUS_COLLECTION, filter=f'book_name == "{BOOK_NAME}"',
                             output_fields=["id"], limit=page, offset=offset)
            if not rows:
                break
            existing.update(r["id"] for r in rows)
            offset += len(rows)
            if len(rows) < page:  # 短页=已取完，避免 offset+limit 超出 Milvus 最大窗口
                break
            if len(existing) >= 1_000_000:
                break
    except Exception as e:
        print(f"[warn] 查询已有来源 id 失败({e})，按全量处理")
        existing = set()

    def rid_for(text):
        return "kg_" + hashlib.md5(text.encode("utf-8")).hexdigest()[:16]

    records = []
    for disease, dept, text in chunks:
        rid = rid_for(text)
        if rid in existing:
            continue
        records.append({
            "id": rid,
            "book_name": BOOK_NAME,
            "edition": "v1",
            "chapter": disease,
            "page_number": 0,
            "chunk_text": text,
            "subject": dept or "综合",
            "part": PART,
            "section": disease,
        })

    total = len(records)
    print(f"[embed] 待嵌入 {total} 条（过滤重复文本后）")
    if not total:
        print("[完成] 无新增，退出")
        return

    cache = {}
    if os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, "r", encoding="utf-8") as f:
                cache = json.load(f)
            print(f"[cache] 载入 {len(cache)} 条嵌入缓存")
        except Exception as e:
            print(f"[warn] 缓存读取失败({e})，忽略")

    from concurrent.futures import ThreadPoolExecutor, as_completed
    results = {}
    need_embed = []
    for i in range(total):
        rid = rid_for(records[i]["chunk_text"])
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
        print(f"[embed] 新增嵌入成功 {done}，失败 {fail}（缓存复用 {total - len(need_embed)}）")
        try:
            for i in need_embed:
                if i in results:
                    cache[rid_for(records[i]["chunk_text"])] = results[i]
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

    batch = 50
    written = 0
    for start in range(0, len(upsert_rows), batch):
        chunk = upsert_rows[start:start + batch]
        cli.upsert(collection_name=MILVUS_COLLECTION, data=chunk)
        written += len(chunk)
        print(f"  ...写入 {written}/{len(upsert_rows)}")
    print(f"[完成] 向量库新增 {written} 条（嵌入失败 {embed_fail}）")


if __name__ == "__main__":
    main()