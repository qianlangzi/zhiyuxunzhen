# -*- coding: utf-8 -*-
"""
病例库扩充脚本：把中文医患对话数据集（Chinese-medical-dialogue-data）
转为 sp_case_config 入门级咨询型病例。

数据来源：6 科室 CSV（department, title, ask, answer），GBK 编码，79 万+ 条
定位：与 CMB 临床病例（difficulty=2）形成梯度的入门级病例（difficulty=1），
      主打疾病话题覆盖，reference_answer 为口语化医生咨询建议。

字段映射（对齐 sp_case_config 全部可用字段，同 import_case.py）
  title                咨询标题（去重键）
  department           数据自带科室标签 -> 院内科室
  difficulty           1（入门）
  patient_profile      JSON：{age,gender,grade,occupation,complaint,personality,
                             presentIllness,pastHistory,allergy}
                       complaint=ask（患者主诉）
  hidden_disease       疾病词典从 title+ask 提取（找不到则跳过该条）
  standard_path_json   通用问诊路径
  preset_exams         '[]'
  knowledge_tags       JSON：[疾病, 科室]
  reference_answer     问：ask / 答：answer
  scoring_points_json  通用评分要点
  is_public=1  admin_audit_status=2  status=1 => 病例广场可见

去重：以 title 判重（幂等）。同名 title 取第一条。
抽样：随机、每科室上限 CAP，控制总量防低质灌满。

依赖：pip install pymysql
运行：python import_dialogue_cases.py
"""
import csv
import io
import json
import os
import random

import pymysql

RAW_ROOT = os.getenv("DIALOGUE_ROOT", r"e:\zhiyu\datasets\raw\Chinese-medical-dialogue-data")
TOTAL_TARGET = int(os.getenv("TOTAL_TARGET", "6000"))       # 目标新增病例总数
PER_DEPT_CAP = int(os.getenv("PER_DEPT_CAP", "2000"))       # 每科室上限
CREATOR_ID = os.getenv("DEFAULT_CREATOR_ID", "1")


def load_dotenv():
    p = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env")
    if not os.path.exists(p):
        return
    for line in open(p, encoding="utf-8"):
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, _, v = line.partition("=")
        os.environ.setdefault(k.strip(), v.strip())


load_dotenv()

HOST = os.getenv("MYSQL_HOST", "127.0.0.1")
PORT = int(os.getenv("MYSQL_PORT", "13306"))
USER = os.getenv("MYSQL_USER", "root")
PASSWORD = os.getenv("MYSQL_PASSWORD", "root123456")
DB = os.getenv("MYSQL_DB", "zhiyu_db")


# 数据自带科室 -> 院内科室
DEPT_MAP = {
    "心血管科": "心血管内科", "神经科": "神经内科", "消化科": "消化内科",
    "妇科": "妇产科", "儿科": "儿科", "骨科": "骨科",
    "男科": "男科", "内科": "综合",
}
# 数据科室名集合（用于识别 CSV 里未预见的科室名，保留原名）
KNOWN_DEPT = set(DEPT_MAP) | {"呼吸科", "内分泌科", "肾内科", "皮肤科", "泌尿科", "肿瘤科", "外科", "感染科"}

# 常见疾病词库（匹配 title+ask，命中即作为 hidden_disease）
DISEASE_TERMS = [
    "高血压", "低血压", "冠心病", "心肌梗死", "心律失常", "心力衰竭", "心绞痛", "血脂异常", "高脂血症",
    "糖尿病", "糖尿病足", "甲状腺功能亢进", "甲状腺功能减退", "甲状腺结节", "甲亢", "痛风", "高尿酸",
    "肺炎", "哮喘", "慢性阻塞性肺疾病", "慢阻肺", "支气管炎", "肺结核", "肺癌", "咳嗽", "咯血", "肺结节",
    "胃炎", "胃溃疡", "胃癌", "十二指肠溃疡", "消化不良", "腹泻", "便秘", "便血", "胰腺炎", "脂肪肝",
    "肝炎", "肝硬化", "乙肝", "胆囊炎", "胆结石", "痔疮", "肠炎", "肠息肉", "阑尾炎",
    "脑梗死", "脑出血", "脑梗", "脑血栓", "癫痫", "帕金森", "偏头痛", "头痛", "眩晕", "面瘫", "阿尔茨海默",
    "肾炎", "肾病综合征", "尿毒症", "肾结石", "尿路感染", "前列腺炎", "前列腺增生", "尿频", "血尿",
    "贫血", "白血病", "再生障碍性贫血", "血小板减少", "淋巴瘤", "骨髓瘤",
    "类风湿关节炎", "风湿", "红斑狼疮", "强直性脊柱炎", "骨质疏松",
    "甲状腺癌", "肝癌", "胃癌", "结肠癌", "乳腺癌", "卵巢癌", "子宫肌瘤", "宫颈癌", "鼻咽癌", "口腔癌",
    "肺炎", "流感", "感冒", "新冠", "发热", "手足口病", "带状疱疹", "荨麻疹", "湿疹", "银屑病",
    "焦虑", "抑郁", "失眠", "神经衰弱",
    "骨折", "脱臼", "关节炎", "颈椎病", "腰椎间盘突出", "肩周炎", "半月板损伤",
    "怀孕", "妊娠", "流产", "先兆流产", "宫外孕", "产后", "月经不调", "痛经", "阴道炎", "盆腔炎",
    "多动症", "佝偻病", "手足口", "黄疸", "哮喘", "肺炎",
]


def get_csv_files():
    found = []
    for root, _, files in os.walk(RAW_ROOT):
        for f in files:
            if f.endswith(".csv"):
                found.append(os.path.join(root, f))
    return found


def read_dialogue(path):
    """读取单个 GBK CSV，容错解码。"""
    try:
        raw = open(path, "rb").read().decode("gbk", errors="replace")
    except FileNotFoundError:
        return []
    rd = csv.reader(io.StringIO(raw))
    rows = []
    try:
        header = next(rd)
        idx = {c: i for i, c in enumerate(header)}
        if not {"department", "title", "ask", "answer"} <= set(idx):
            print(f"   [skip] 列缺失: {path}", header)
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


def clean(raw_dept):
    """数据科室 -> 院内科室，无法识别返回空串。"""
    return DEPT_MAP.get(raw_dept, raw_dept if raw_dept in KNOWN_DEPT else "")


def extract_disease(title, ask):
    """从 title+ask 找首个命中疾病词；未命中返回空（该条放弃）。"""
    text = f"{title} {ask}"
    for term in DISEASE_TERMS:
        if term in text:
            return term
    return ""


def make_row(rec, dep, disease):
    title = rec["title"]
    ask = rec["ask"]
    answer = rec["answer"]
    profile = {
        "age": "",
        "gender": "",
        "grade": "大四",
        "occupation": "",
        "complaint": ask[:200],
        "personality": ["话多" if len(ask) > 60 else "普通患者"],
        "presentIllness": ask[:450],
        "pastHistory": "",
        "allergy": "不详",
    }
    scoring = [
        {"label": "问诊要点1", "fullMark": 25, "criteria": "正确倾听并按需追问", "deduct": "回答不完整酌情扣分"},
        {"label": "问诊要点2", "fullMark": 25, "criteria": "给出合理建议", "deduct": "建议不具体酌情扣分"},
        {"label": "问诊要点3", "fullMark": 25, "criteria": "疾病知识准确", "deduct": "知识错误酌情扣分"},
        {"label": "问诊要点4", "fullMark": 25, "criteria": "医患沟通友好", "deduct": "沟通生硬酌情扣分"},
    ]
    return (
        int(CREATOR_ID),          # creator_id
        None,                     # source_case_id
        title,
        dep,
        1,                        # difficulty
        json.dumps(profile, ensure_ascii=False),
        disease,                  # hidden_disease
        json.dumps(["问诊评估（主诉、现病史）", "针对性追问", "解释与健康建议"], ensure_ascii=False),
        "[]",
        json.dumps([disease, dep], ensure_ascii=False),
        f"问：{ask}\n答：{answer}",
        json.dumps(scoring, ensure_ascii=False),
        1, 0, 0.0, 2, 1, 1,
    )


def connect():
    return pymysql.connect(
        host=HOST, port=PORT, user=USER, password=PASSWORD,
        database=DB, charset="utf8mb4", connect_timeout=10,
    )


def load_existing(cur):
    cur.execute("SELECT title FROM sp_case_config WHERE is_deleted = 0")
    return {r[0]: True for r in cur.fetchall() if r[0]}


def main():
    random.seed(42)
    print(f"[read] 数据根目录: {RAW_ROOT}")
    files = get_csv_files()
    print(f"[read] 发现 {len(files)} 个 CSV")

    candidates = []  # (dept, disease, rec)
    for path in files:
        rows = read_dialogue(path)
        before = len(rows)
        for rec in rows:
            dep = clean(rec["department"])
            if not dep:
                continue
            ask, answer, title = rec["ask"], rec["answer"], rec["title"]
            if len(ask) < 10 or len(answer) < 15 or len(title) < 5:
                continue
            disease = extract_disease(title, ask)
            if not disease:
                continue
            candidates.append((dep, disease, rec))
        print(f"   {os.path.basename(path)}: {before} -> 合格 {len(candidates)} 累计")

    print(f"[sample] 合格候选 {len(candidates)} 条，目标新增 {TOTAL_TARGET}（每科室上限 {PER_DEPT_CAP}）")
    # 每科室抽样，尽量均衡
    by_dept: dict[str, list] = {}
    order = []
    for dep, disease, rec in candidates:
        by_dept.setdefault(dep, []).append((disease, rec))
        if dep not in order:
            order.append(dep)
    picked = []
    used_title = set()
    for dep in order:
        pool = by_dept[dep]
        random.shuffle(pool)
        n = 0
        for disease, rec in pool:
            if len(picked) >= TOTAL_TARGET:
                break
            if n >= PER_DEPT_CAP:
                break
            title = rec["title"]
            if title in used_title:
                continue
            used_title.add(title)
            picked.append((dep, disease, rec))
            n += 1

    print(f"[select] 拟入库 {len(picked)} 例")
    if not picked:
        print("[完成] 无候选，退出")
        return

    conn = connect()
    cur = conn.cursor()
    existing = load_existing(cur)
    print(f"[db] 库内已有病例 {len(existing)} 例")

    rows = []
    for dep, disease, rec in picked:
        if rec["title"] in existing:
            continue
        rows.append(make_row(rec, dep, disease))

    sql = (
        "INSERT INTO sp_case_config "
        "(creator_id, source_case_id, title, department, difficulty, patient_profile, "
        " hidden_disease, standard_path_json, preset_exams, knowledge_tags, reference_answer, "
        " scoring_points_json, is_public, reference_count, rating_avg, admin_audit_status, "
        " version, status) "
        "VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)"
    )
    batch = 30
    for start in range(0, len(rows), batch):
        cur.executemany(sql, rows[start:start + batch])
        conn.commit()
    print(f"[完成] 本次新入库病例 {len(rows)} 例")
    cur.close()
    conn.close()


if __name__ == "__main__":
    main()