# -*- coding: utf-8 -*-
"""
题库导入脚本：把 CMB 真实题目灌入 practice_question

数据来源
  - CMB-train（约 26.9 万题，含答案，无解析）：蓄水池抽样 N_train 题
  - CMB-val（280 题，含答案解析）：全量导入
  - 跳过「C型选择题」（共享选项，结构特殊）；只导入单选/多选

字段映射（不漏字段、对齐 practice_question 表）
  question_type   单项选择题->single_choice / 多项选择题->multiple_choice
  department      由 exam_subject 归一到临床科室
  knowledge_tag   exam_subject（去掉职称/考试后缀后的专科名）
  title           question
  options_json    从 option dict 按键顺序转 JSON 数组
  answer          选项字母转下标（单选纯下标；多选逗号分隔，如 "0,1,2"）
  explanation     val 有，train 无（置 NULL）
  difficulty      2（标准）
  status=1  admin_audit_status=2  => 前台可见

去重策略（幂等，可重复运行）
  - 运行前从 practice_question 加载全部已有 title 到内存
  - 本批次内再维护 title 集合去重
  - 时间戳/状态列由 DB 默认值填充

依赖：pip install pymysql   （需已安装）
运行：python import_question.py
"""
import os
import random
import json
import sys

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

# ---------- 环境变量（本地用默认值；服务器改 .env） ----------
HOST = os.getenv("MYSQL_HOST", "127.0.0.1")
PORT = int(os.getenv("MYSQL_PORT", "13306"))
USER = os.getenv("MYSQL_USER", "root")
PASSWORD = os.getenv("MYSQL_PASSWORD", "root123456")
DB = os.getenv("MYSQL_DB", "zhiyu_db")

TRAIN_FILE = os.getenv(
    "CMB_TRAIN",
    r"e:\zhiyu\datasets\raw\_extract_train\CMB\CMB-Exam\CMB-train\CMB-train-merge.json",
)
VAL_FILE = os.getenv(
    "CMB_VAL",
    r"e:\zhiyu\datasets\raw\CMB\CMB-Exam\CMB-val\CMB-val-merge.json",
)
N_TRAIN = int(os.getenv("N_TRAIN", "50000"))  # train 抽样数量

# ---------- 选项字母 -> 下标 ----------
LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"


def letter_to_index(letter):
    return LETTERS.index(letter)


def convert_answer(answer, ordered_keys):
    """把 'D' / 'BCDE' 转成下标字符串；单选返回 '0'，多选返回 '0,1,2'。"""
    if not answer:
        return None
    idxs = []
    for ch in answer.strip():
        if ch not in ordered_keys:
            return None
        idxs.append(ordered_keys.index(ch))
    if not idxs:
        return None
    return ",".join(str(i) for i in idxs)


# ---------- 科室归一：exam_subject / 病例 -> 临床科室 ----------
def normalize_department(subject):
    s = subject or ""
    # 去职称 / 考试类后缀
    for suf in [
        "副主任、主任医师职称考试", "职称考试", "高级职称", "主治医师", "执业助理医师",
        "执业医师", "执业药师", "执业中药师", "资格考试", "资格证", "主管技师",
        "主管护师", "主管药师", "初(级)|初级", "技术（士）", "技术（师）",
        "（士）", "（师）", "错题TO", "错题top", "top500", "top1500", "考试", "考研",
    ]:
        s = s.replace(suf, "")
    s = s.replace("临床执业", "").replace("中医执业", "").strip()
    return s or subject


def map_department(subject):
    """把专科名映射到系统内的临床科室（keyword 命中取第一个）。"""
    s = normalize_department(subject) or subject
    rules = [
        (["心", "冠脉", "血管内科"], "心血管内科"),
        (["呼吸", "肺", "结核"], "呼吸内科"),
        (["消化", "胃肠", "肝胆", "肛门"], "消化内科"),
        (["神经", "神内"], "神经内科"),
        (["内分泌", "糖尿病"], "内分泌科"),
        (["肾"], "肾内科"),
        (["血液", "血"], "血液科"),
        (["风湿", "免疫"], "风湿免疫科"),
        (["传染", "感染"], "感染科"),
        (["儿科", "小儿"], "儿科"),
        (["妇产", "产科", "妇科"], "妇产科"),
        (["外科", "疝", "肝胆外科", "胃肠外科"], "外科"),
        (["骨科", "骨"], "骨科"),
        (["泌尿"], "泌尿外科"),
        (["口腔", "牙"], "口腔科"),
        (["眼科", "眼"], "眼科"),
        (["耳鼻咽喉", "耳鼻"], "耳鼻咽喉科"),
        (["皮肤", "性病"], "皮肤科"),
        (["精神", "心理", "心理咨询"], "精神科"),
        (["康复", "理疗"], "康复医学科"),
        (["麻醉"], "麻醉科"),
        (["急诊", "危重", "重症"], "急诊科"),
        (["影像", "放射", "超声", "核医学", "心电"], "医学影像科"),
        (["检验", "理化", "生物信息", "输血"], "检验科"),
        (["病理", "病案"], "病理科"),
        (["药学", "药士", "药师", "中药", "药理学"], "药剂科"),
        (["护理"], "护理部"),
        (["中医", "针灸", "温病", "内经", "伤寒", "金匮", "中药学"], "中医"),
        (["生理", "生化", "解剖", "免疫", "微生物", "寄生虫", "病生",
          "病理生理", "遗传", "细胞", "组织", "胚胎", "生物"], "基础医学"),
        (["诊断学", "物理诊断", "实验诊断", "症状"], "诊断学"),
    ]
    for kws, dep in rules:
        for kw in kws:
            if kw in s:
                return dep
    return "综合"


def de_tag(subject):
    return normalize_department(subject)


# ---------- 数据库 ----------
def connect():
    return pymysql.connect(
        host=HOST, port=PORT, user=USER, password=PASSWORD,
        database=DB, charset="utf8mb4", connect_timeout=10,
    )


def load_existing_titles(cur):
    """加载已在库的 title 集合，用于幂等去重。"""
    cur.execute("SELECT title FROM practice_question WHERE is_deleted = 0")
    titles = set()
    for (t,) in cur.fetchall():
        if t:
            titles.add(t)
    return titles


def make_row(item, existing_titles, seen):
    """把 CMB 单条转成插入元组；返回 None 表示跳过。"""
    qtype = item.get("question_type")
    if qtype == "单项选择题":
        question_type = "single_choice"
    elif qtype == "多项选择题":
        question_type = "multiple_choice"
    else:
        return None  # 跳过 C 型选择题等

    title = (item.get("question") or "").strip()
    option = item.get("option") or {}
    if not title or not option or not isinstance(option, dict):
        return None

    ordered_keys = list(option.keys())
    options = [str(option[k]).strip() for k in ordered_keys]
    answer = convert_answer(item.get("answer"), ordered_keys)
    if answer is None:
        return None

    # 单选应对应 1 个下标；多选应对应 1~K 个
    n_ans = answer.count(",") + 1
    if question_type == "single_choice" and n_ans != 1:
        return None

    # 去重
    if title in existing_titles or title in seen:
        return None

    subject = item.get("exam_subject") or ""
    explanation = item.get("explanation")
    return (
        question_type,
        map_department(subject),
        de_tag(subject),
        title,
        json.dumps(options, ensure_ascii=False),
        answer,
        explanation,
        2,        # difficulty 标准
        1,        # status 上架
        2,        # admin_audit_status 审核通过
    )


def insert_rows(cur, rows):
    sql = (
        "INSERT INTO practice_question "
        "(question_type, department, knowledge_tag, title, options_json, "
        " answer, explanation, difficulty, status, admin_audit_status) "
        "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)"
    )
    cur.executemany(sql, rows)


def stream_train(limit):
    """流式读取 train，蓄水池抽样 limit 条有效题目。"""
    import ijson
    choose = []
    seen = set()
    i = 0
    with open(TRAIN_FILE, "rb") as f:
        for item in ijson.items(f, "item"):
            if make_row(item, set(), set()) is None:
                continue
            i += 1
            if len(choose) < limit:
                choose.append(item)
            else:
                j = random.randint(0, i - 1)
                if j < limit:
                    choose[j] = item
    print(f"[train] 有效候选 {i} 条，蓄水池抽样 {len(choose)} 条")
    return choose


def load_val():
    with open(VAL_FILE, encoding="utf-8") as f:
        return json.load(f)


def main():
    random.seed(20260827)
    conn = connect()
    cur = conn.cursor()
    existing = load_existing_titles(cur)
    print(f"[db] 库内已有题目 {len(existing)} 条")

    seen = set(existing)
    rows = []

    # 1) train 抽样
    for item in stream_train(N_TRAIN):
        r = make_row(item, existing, seen)
        if r:
            rows.append(r)
            seen.add(r[3])
    print(f"[train] 准备入库 {len(rows)} 条")

    # 2) val 全量（含解析）
    val_rows = 0
    for item in load_val():
        r = make_row(item, existing, seen)
        if r:
            rows.append(r)
            seen.add(r[3])
            val_rows += 1
    print(f"[val]  准备入库 {val_rows} 条（含解析）")

    # 分批提交
    batch = 500
    for start in range(0, len(rows), batch):
        chunk = rows[start : start + batch]
        insert_rows(cur, chunk)
        conn.commit()
        print(f"  已提交 {len(chunk)} 条（累计 {min(start + batch, len(rows))}/{len(rows)}）")

    cur.close()
    conn.close()
    print(f"[完成] 本次新入库 {len(rows)} 条题目")


if __name__ == "__main__":
    main()