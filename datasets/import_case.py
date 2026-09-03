# -*- coding: utf-8 -*-
"""
病例库导入脚本：把 CMB-Clin 真实病例灌入 sp_case_config

数据来源：CMB-Clin-qa.json（74 例「病例描述 + 多轮问答」）

字段映射（对齐 sp_case_config 全部可用字段）
  title                去掉「案例分析-」前缀后的标题
  department           按标题/诊断关键词映射到科室
  difficulty           2（标准）
  patient_profile      JSON：{age, gender, grade, occupation, complaint,
                           personality, presentIllness, pastHistory}
                       age/gender/主诉 从病例描述中尝试解析，缺省用空串
  hidden_disease       取第一轮问答答案中的「诊断」行
  standard_path_json   JSON 数组：通用标准 SP 问诊路径
  preset_exams         '[]'（无结构化检查单则留空数组）
  knowledge_tags       JSON 数组：[标题疾病, 科室]
  reference_answer     拼接全部分轮问答 Q&A
  scoring_points_json  JSON 数组：按问答数生成通用评分要点
  is_public=1  admin_audit_status=2  status=1  => 病例广场可见

去重策略（幂等，可重复运行）
  - 运行前加载已有 title 到内存 + 本批次内去重
  - 以 title 判重（按唯一约束前 100 字符）

依赖：pip install pymysql
运行：python import_case.py
"""
import os
import json
import re

import pymysql

def load_dotenv():
    """加载脚本同目录下的 .env（无外部依赖）。"""
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

CLIN_FILE = os.getenv(
    "CMB_CLIN",
    r"e:\zhiyu\datasets\raw\CMB\CMB-Clin\CMB-Clin-qa.json",
)
# 入库病例所属教师 ID（sys_user.role=1 的教师），服务器部署时按实际账号调整
CREATOR_ID = os.getenv("DEFAULT_CREATOR_ID", "1")


def connect():
    return pymysql.connect(
        host=HOST, port=PORT, user=USER, password=PASSWORD,
        database=DB, charset="utf8mb4", connect_timeout=10,
    )


def map_department(text):
    t = text or ""
    rules = [
        (["疝", "腹外"], "普外科"),
        (["心", "冠脉", "心梗", "胸痛"], "心血管内科"),
        (["呼吸", "肺炎", "哮喘", "慢阻肺", "咯血"], "呼吸内科"),
        (["消化", "胃肠", "腹痛", "消化道", "肝炎", "肝硬"], "消化内科"),
        (["神经", "脑", "卒中", "癫痫", "头痛"], "神经内科"),
        (["内分泌", "糖尿病", "甲状腺"], "内分泌科"),
        (["肾", "尿毒症", "透析"], "肾内科"),
        (["血液", "贫血", "白血病"], "血液科"),
        (["风湿", "免疫"], "风湿免疫科"),
        (["传染", "感染", "发热"], "感染科"),
        (["儿科", "小儿"], "儿科"),
        (["妇产", "妊娠", "妊娠晚期"], "妇产科"),
        (["骨折", "骨", "创伤"], "骨科"),
        (["泌尿", "结石", "前列腺"], "泌尿外科"),
        (["慢性肾功能衰竭"], "肾内科"),
        (["中毒", "农药"], "急诊科"),
        (["休克", "严重感染"], "急诊科"),
    ]
    for kws, dep in rules:
        for kw in kws:
            if kw in t:
                return dep
    return "综合"


def parse_patient_profile(description):
    """从病例描述里尽力解析年龄/性别/主诉。"""
    desc = description or ""
    match = re.search(r"男[，,\s]*?(\d+)岁", desc) or re.search(r"(\d+)岁[，,\s]*?男", desc)
    male = re.search(r"男[，,\s]*?\d+岁|\d+岁[，,\s]*?男", desc)
    female = re.search(r"女[，,\s]*?\d+岁|\d+岁[，,\s]*?女", desc)
    age = match.group(1) if match else ""
    if male:
        gender = "男"
    elif female:
        gender = "女"
    else:
        gender = ""
    # 主诉：取「主诉」行之后的内容
    complaint = ""
    m = re.search(r"主诉[：:]\s*(.+)", desc)
    if m:
        complaint = m.group(1).split("\n")[0].strip()
    return {
        "age": age,
        "gender": gender,
        "grade": "大四",
        "occupation": "",
        "complaint": complaint,
        "personality": ["隐瞒病史"],
        "presentIllness": desc.strip()[:450],
        "pastHistory": "",
        "allergy": "不详",
    }


def extract_diagnosis(qa_pairs):
    """从第一轮问答答案中提取「诊断」行。"""
    if not qa_pairs:
        return ""
    for qa in qa_pairs:
        ans = (qa.get("answer") or "").strip()
        lines = [ln.strip() for ln in ans.splitlines() if ln.strip()]
        for ln in lines:
            if len(ln) >= 8 and ("诊断" in ln or ln.endswith("。")):
                return ln[:120]
    return (qa_pairs[0].get("answer") or "").strip()[:120]


def build_reference_answer(qa_pairs):
    parts = []
    for i, qa in enumerate(qa_pairs, 1):
        q = (qa.get("question") or "").strip()
        a = (qa.get("answer") or "").strip()
        parts.append(f"{i}. 问：{q}\n    答：{a}")
    return "\n\n".join(parts)


def build_scoring_points(qa_pairs):
    n = max(len(qa_pairs), 4)
    full = 100 // n
    points = []
    for i, qa in enumerate(qa_pairs[: n], 1):
        q = (qa.get("question") or "").strip()[:30]
        points.append({
            "label": f"问诊要点{i}",
            "fullMark": full,
            "criteria": f"正确回答：{q}",
            "deduct": "回答不完整酌情扣分",
        })
    return points


def make_row(rec, existing, seen):
    raw_title = (rec.get("title") or "").strip()
    title = raw_title.replace("案例分析-", "").strip() or raw_title
    if title in existing or title in seen:
        return None

    description = rec.get("description") or ""
    qa_pairs = rec.get("QA_pairs") or []
    diag = extract_diagnosis(qa_pairs)
    comb = (title + diag)

    return (
        int(CREATOR_ID),                        # creator_id
        None,                                   # source_case_id
        title,
        map_department(comb),
        2,                                      # difficulty
        json.dumps(parse_patient_profile(description), ensure_ascii=False),
        diag,                                   # hidden_disease
        json.dumps([
            "问诊评估（主诉、现病史、既往史）",
            "体格检查",
            "辅助检查（实验室、影像）",
            "诊断与鉴别诊断",
            "制定治疗方案",
        ], ensure_ascii=False),                 # standard_path_json
        "[]",                                   # preset_exams
        json.dumps([title, map_department(comb)], ensure_ascii=False),  # knowledge_tags
        build_reference_answer(qa_pairs),       # reference_answer
        json.dumps(build_scoring_points(qa_pairs), ensure_ascii=False),  # scoring_points_json
        1,                                      # is_public
        0,                                      # reference_count
        0.0,                                    # rating_avg
        2,                                      # admin_audit_status
        1,                                      # version
        1,                                      # status
    )


def load_existing(cur):
    cur.execute("SELECT title FROM sp_case_config WHERE is_deleted = 0")
    return {row[0] for row in cur.fetchall() if row[0]}


def main():
    data = json.load(open(CLIN_FILE, encoding="utf-8"))
    recs = data if isinstance(data, list) else (list(data.values())[0] if isinstance(data, dict) else [])
    print(f"[clin] 源数据 {len(recs)} 例")

    conn = connect()
    cur = conn.cursor()
    existing = load_existing(cur)
    print(f"[db] 库内已有病例 {len(existing)} 例")

    seen = set(existing)
    rows = []
    for rec in recs:
        r = make_row(rec, existing, seen)
        if r:
            rows.append(r)
            seen.add(r[2])

    sql = (
        "INSERT INTO sp_case_config "
        "(creator_id, source_case_id, title, department, difficulty, patient_profile, "
        " hidden_disease, standard_path_json, preset_exams, knowledge_tags, reference_answer, "
        " scoring_points_json, is_public, reference_count, rating_avg, admin_audit_status, "
        " version, status) "
        "VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)"
    )
    batch = 20
    for start in range(0, len(rows), batch):
        chunk = rows[start : start + batch]
        cur.executemany(sql, chunk)
        conn.commit()
    print(f"[完成] 本次新入库病例 {len(rows)} 例")
    cur.close()
    conn.close()


if __name__ == "__main__":
    main()