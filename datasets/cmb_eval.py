#!/usr/bin/env python3
"""CMB 中文医学综合评测脚本（P2-2 模型医学 QA 量化指标）

用途：在 CMB-Exam 风格的医学单选题上评测当前配置的 LLM（deepseek-chat 等），
产出按学科分类的准确率与总体准确率，供大赛材料/管理端呈现「模型微调/优化」量化指标。

数据来源：
  1. --data 指定本地 CMB-Exam val JSONL（官方格式见 datasets/CMB.md），每条：
     {"id":0,"exam_type":"CMB-Exam","exam_name":"...","question_type":"单选",
      "question":"...","option":"A...\nB...\nC...\nD...","answer":"B","analysis":"..."}
  2. 未提供时使用内置样例集（与 CMB 同结构，覆盖内/外/生理/病理/药理/诊断等学科），
     保证无网络也能出可复现指标。

模型配置：优先读环境变量（LLM_BASE_URL / LLM_API_KEY / LLM_MODEL），
否则回退读取 ../ai/.env 中的同名配置（与 AI 中台同源，指标口径一致）。

用法：
  python cmb_eval.py --limit 20                 # 内置样例，跑 20 题
  python cmb_eval.py --data cmb_val.jsonl --limit 100
  python cmb_eval.py --data cmb_val.jsonl --save result.json --md result.md
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.request
from collections import defaultdict

# ---------------------------------------------------------------- 内置样例集
# 与 CMB-Exam val 同结构（question / option / answer / exam_name / analysis）。
# 仅作离线兜底与口径演示；正式指标以 --data 提供的大规模评测为准。
BUILTIN_SAMPLES: list[dict] = [
    {
        "exam_name": "内科学-心血管",
        "question_type": "单选",
        "question": "急性心肌梗死最常见的死亡原因是什么？",
        "option": "A.心律失常\nB.心力衰竭\nC.心源性休克\nD.心脏破裂\nE.感染",
        "answer": "A",
        "analysis": "急性心梗早期死亡以恶性室性心律失常（室颤）最常见，多在发病 24h 内。",
    },
    {
        "exam_name": "内科学-心血管",
        "question_type": "单选",
        "question": "二尖瓣狭窄最早出现的血流动力学改变是？",
        "option": "A.右心室肥大\nB.左心房压力升高\nC.肺动脉高压\nD.左心室扩大\nE.主动脉瓣反流",
        "answer": "B",
        "analysis": "二尖瓣狭窄首先导致左心房压力升高与左房扩大，进而继发肺淤血与肺动脉高压。",
    },
    {
        "exam_name": "内科学-呼吸",
        "question_type": "单选",
        "question": "诊断慢性阻塞性肺疾病（COPD）的肺功能金标准是？",
        "option": "A.用力肺活量下降\nB.吸入支气管扩张剂后 FEV1/FVC<0.70\nC.残气量升高\nD.弥散功能下降\nE.气道阻力升高",
        "answer": "B",
        "analysis": "吸入支气管扩张剂后 FEV1/FVC<0.70 提示持续气流受限，是 COPD 的肺功能诊断标准。",
    },
    {
        "exam_name": "外科学-普外",
        "question_type": "单选",
        "question": "急性阑尾炎最具诊断意义的体征是？",
        "option": "A.麦氏点固定压痛\nB.右下腹反跳痛\nC.结肠充气试验阳性\nD.腰大肌试验阳性\nE.闭孔内肌试验阳性",
        "answer": "A",
        "analysis": "麦氏点固定压痛是急性阑尾炎最有诊断意义的体征；反跳痛提示炎症累及壁层腹膜。",
    },
    {
        "exam_name": "外科学-骨科",
        "question_type": "单选",
        "question": "Colles 骨折最典型的畸形是？",
        "option": "A.餐叉样畸形\nB.枪刺样畸形\nC.垂腕畸形\nD.爪形手\nE.猿手畸形",
        "answer": "A",
        "analysis": "Colles（伸直型桡骨远端）骨折典型畸形为餐叉样（银叉样）与枪刺样畸形。",
    },
    {
        "exam_name": "生理学",
        "question_type": "单选",
        "question": "静息状态下细胞膜内外的电位差主要取决于？",
        "option": "A.钠泵活动\nB.钾离子的平衡电位\nC.氯离子浓度梯度\nD.钠离子内流\nE.钙离子外流",
        "answer": "B",
        "analysis": "静息电位主要由 K+ 外流形成的钾平衡电位决定，是形成静息电位的基础。",
    },
    {
        "exam_name": "生理学",
        "question_type": "单选",
        "question": "心动周期中左心室内压最高的时期是？",
        "option": "A.心房收缩期\nB.等容收缩期\nC.快速射血期\nD.减慢射血期\nE.等容舒张期",
        "answer": "C",
        "analysis": "快速射血期左室压达峰值，主动脉瓣开放，血液快速进入主动脉。",
    },
    {
        "exam_name": "病理学",
        "question_type": "单选",
        "question": "纤维素性炎症最常见于哪种组织？",
        "option": "A.黏膜\nB.浆膜\nC.皮肤\nD.骨骼肌\nE.神经组织",
        "answer": "B",
        "analysis": "纤维素性炎好发于浆膜（胸膜、心包膜、腹膜）、肺和黏膜，如大叶性肺炎、绒毛心。",
    },
    {
        "exam_name": "病理学",
        "question_type": "单选",
        "question": "恶性肿瘤区别于良性肿瘤最重要的组织学特征是？",
        "option": "A.生长较快\nB.异型性明显\nC.体积较大\nD.出血坏死\nE.压迫周围组织",
        "answer": "B",
        "analysis": "异型性是恶性肿瘤最重要的组织学特征，反映细胞分化程度低。",
    },
    {
        "exam_name": "药理学",
        "question_type": "单选",
        "question": "阿托品中毒时解救的首选药物是？",
        "option": "A.毛果芸香碱\nB.新斯的明\nC.毒扁豆碱\nD.山莨菪碱\nE.肾上腺素",
        "answer": "A",
        "analysis": "阿托品为 M 受体阻断剂，中毒解救首选 M 受体激动剂毛果芸香碱。",
    },
    {
        "exam_name": "药理学",
        "question_type": "单选",
        "question": "青霉素最常见的过敏反应类型是？",
        "option": "A.溶血性贫血\nB.过敏性休克\nC.荨麻疹\nD.血清病样反应\nE.药热",
        "answer": "B",
        "analysis": "过敏性休克是青霉素最严重最常见的过敏反应，用药前必须皮试。",
    },
    {
        "exam_name": "诊断学-体格检查",
        "question_type": "单选",
        "question": "左心衰竭最早出现的典型体征是？",
        "option": "A.颈静脉怒张\nB.双肺底湿啰音\nC.肝颈静脉回流征阳性\nD.下肢凹陷性水肿\nE.胸水",
        "answer": "B",
        "analysis": "双肺底湿啰音是左心衰竭肺淤血的早期体征；A/C/D 多为右心衰竭表现。",
    },
    {
        "exam_name": "诊断学-心电图",
        "question_type": "单选",
        "question": "急性下壁心肌梗死典型的心电图改变出现在哪些导联？",
        "option": "A.V1-V3\nB.V4-V6\nC.I、aVL\nD.II、III、aVF\nE.V7-V9",
        "answer": "D",
        "analysis": "下壁心梗对应 II、III、aVF 导联；前间壁 V1-V3；侧壁 I、aVL、V5-V6。",
    },
    {
        "exam_name": "儿科学",
        "question_type": "单选",
        "question": "新生儿生理性黄疸一般出现于生后几天内？",
        "option": "A.出生 24 小时内\nB.出生后 2-3 天\nC.出生后 1 周\nD.出生后 2 周\nE.出生后 3 周",
        "answer": "B",
        "analysis": "生理性黄疸多于生后 2-3 天出现；24 小时内出现多提示病理性黄疸。",
    },
    {
        "exam_name": "传染病学",
        "question_type": "单选",
        "question": "乙肝大三阳的血清学指标组合是？",
        "option": "A.HBsAg(+)、HBeAg(+)、抗-HBc(+)\nB.HBsAg(+)、抗-HBe(+)、抗-HBc(+)\nC.HBsAg(+)、抗-HBs(+)、HBeAg(+)\nD.抗-HBs(+)、抗-HBe(+)、抗-HBc(+)\nE.HBsAg(+)、HBeAg(+)、抗-HBs(+)",
        "answer": "A",
        "analysis": "大三阳为 HBsAg、HBeAg、抗-HBc 三项阳性，提示病毒复制活跃、传染性强。",
    },
    {
        "exam_name": "妇产科学",
        "question_type": "单选",
        "question": "正常胎心率的范围是？",
        "option": "A.80-100 次/分\nB.100-120 次/分\nC.110-160 次/分\nD.160-180 次/分\nE.180-200 次/分",
        "answer": "C",
        "analysis": "正常胎心率为 110-160 次/分；持续 <110 或 >160 提示胎儿窘迫可能。",
    },
]


# ---------------------------------------------------------------- 配置加载
def load_dotenv(path: str) -> dict[str, str]:
    """简易 .env 解析（仅取 KEY=VALUE，忽略注释/空行）"""
    data: dict[str, str] = {}
    try:
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, _, val = line.partition("=")
                data[key.strip()] = val.strip().strip("\"'")
    except OSError:
        pass
    return data


def resolve_llm_config() -> dict[str, str]:
    """环境变量优先，回退 ../ai/.env"""
    env = {}
    env_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ai", ".env")
    env = load_dotenv(env_path)
    for key in ("LLM_BASE_URL", "LLM_API_KEY", "LLM_MODEL"):
        if os.environ.get(key):
            env[key] = os.environ[key]
    base = env.get("LLM_BASE_URL", "").rstrip("/")
    api_key = env.get("LLM_API_KEY", "")
    model = env.get("LLM_MODEL", "deepseek-chat")
    return {"base_url": base, "api_key": api_key, "model": model}


# ---------------------------------------------------------------- 数据加载
def load_data(path: str | None, limit: int | None) -> tuple[list[dict], str]:
    if path:
        rows: list[dict] = []
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    rows.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
        src = path
    else:
        rows = [dict(s) for s in BUILTIN_SAMPLES]
        src = "builtin-samples"
    if limit and limit > 0:
        rows = rows[:limit]
    return rows, src


def normalize_option(option: str) -> list[str]:
    """把 option 文本拆成 [A..., B..., ...] 列表"""
    opts = re.split(r"\n(?=[A-E][.、:])", option.strip())
    return [o.strip() for o in opts if o.strip()]


def build_prompt(q: dict) -> str:
    opts = normalize_option(q.get("option", ""))
    opt_block = "\n".join(f"{o}" for o in opts)
    return (
        f"【医学单选题】请根据医学知识选择唯一正确答案。\n"
        f"题目：{q.get('question', '')}\n{opt_block}\n"
        f"请只输出答案选项字母（如 A），不要输出其他内容。"
    )


def extract_answer(text: str) -> str:
    """从模型输出中提取 A-E 答案字母"""
    m = re.search(r"\b([A-E])\b", text)
    if m:
        return m.group(1)
    return ""


# ---------------------------------------------------------------- LLM 调用
def ask_llm(cfg: dict, prompt: str, timeout: float = 40.0) -> str:
    """OpenAI 兼容 chat completions 单次调用，返回模型原始输出"""
    if not cfg["base_url"] or not cfg["api_key"]:
        raise RuntimeError("未配置 LLM_BASE_URL / LLM_API_KEY，无法评测真实模型")
    url = cfg["base_url"] + "/chat/completions"
    body = {
        "model": cfg["model"],
        "messages": [
            {"role": "user", "content": prompt},
        ],
        "temperature": 0.0,
        "max_tokens": 128,
    }
    req = urllib.request.Request(
        url,
        data=json.dumps(body).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {cfg['api_key']}",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    return (data.get("choices") or [{}])[0].get("message", {}).get("content", "")


# ---------------------------------------------------------------- 主流程
def run_eval(cfg: dict, rows: list[dict], max_retry: int = 2) -> dict:
    results: list[dict] = []
    for i, q in enumerate(rows, 1):
        ground = (q.get("answer") or "").strip().upper()[:1]
        pred = ""
        err = ""
        for attempt in range(max_retry + 1):
            try:
                raw = ask_llm(cfg, build_prompt(q))
                pred = extract_answer(raw)
                if pred:
                    break
                err = "empty_answer"
            except Exception as exc:  # noqa: BLE001
                err = f"{type(exc).__name__}: {exc}"
                if attempt < max_retry:
                    time.sleep(1.0)
        results.append(
            {
                "index": i,
                "exam_name": q.get("exam_name", "未分类"),
                "question": (q.get("question", "")[:60]),
                "ground_truth": ground,
                "prediction": pred,
                "correct": bool(pred and pred == ground),
                "error": err if (not pred) else None,
            }
        )
        flag = "✔" if results[-1]["correct"] else "✘"
        print(f"[{i}/{len(rows)}] {flag} 期望={ground} 预测={pred or '∅'} {results[-1]['exam_name']}")

    per_cat: dict[str, dict] = {}
    for r in results:
        c = per_cat.setdefault(r["exam_name"], {"total": 0, "correct": 0})
        c["total"] += 1
        c["correct"] += int(r["correct"])
    cat_rows = [
        {
            "exam_name": k,
            "total": v["total"],
            "correct": v["correct"],
            "accuracy": round(v["correct"] / v["total"], 4) if v["total"] else 0.0,
        }
        for k, v in sorted(per_cat.items())
    ]
    total = len(results)
    correct = sum(1 for r in results if r["correct"])
    return {
        "model": cfg["model"],
        "total": total,
        "correct": correct,
        "accuracy": round(correct / total, 4) if total else 0.0,
        "by_category": cat_rows,
        "details": results,
    }


def to_markdown(result: dict) -> str:
    lines = [
        f"# CMB 医学评测结果（模型：{result['model']}）",
        "",
        f"- 题量：{result['total']}｜答对：{result['correct']}｜**总体准确率：{result['accuracy']*100:.1f}%**",
        "",
        "| 学科 | 题量 | 答对 | 准确率 |",
        "|---|---|---|---|",
    ]
    for c in result["by_category"]:
        lines.append(
            f"| {c['exam_name']} | {c['total']} | {c['correct']} | {c['accuracy']*100:.1f}% |"
        )
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description="CMB 中文医学综合评测")
    ap.add_argument("--data", default=None, help="CMB-Exam val JSONL 路径（缺省用内置样例）")
    ap.add_argument("--limit", type=int, default=0, help="最多评测题数（0=全部）")
    ap.add_argument("--save", default=None, help="结果 JSON 保存路径")
    ap.add_argument("--md", default=None, help="结果 Markdown 保存路径")
    args = ap.parse_args()

    cfg = resolve_llm_config()
    if not cfg["base_url"] or not cfg["api_key"]:
        print("错误：未配置 LLM_BASE_URL / LLM_API_KEY（环境变量或 ../ai/.env）", file=sys.stderr)
        return 2

    rows, src = load_data(args.data, args.limit)
    print(f"评测数据源：{src}｜共 {len(rows)} 题｜模型：{cfg['model']}｜base：{cfg['base_url']}")
    result = run_eval(cfg, rows)

    print("\n========== CMB 评测结果 ==========")
    print(to_markdown(result))

    if args.save:
        with open(args.save, "w", encoding="utf-8") as f:
            json.dump(result, f, ensure_ascii=False, indent=2)
        print(f"\n已保存 JSON：{args.save}")
    if args.md:
        with open(args.md, "w", encoding="utf-8") as f:
            f.write(to_markdown(result))
        print(f"已保存 Markdown：{args.md}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
