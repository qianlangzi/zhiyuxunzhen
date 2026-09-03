"""预置带 result 的演示病例检查菜单（2026-09-03 报告卡 L0/L1 实施）。

直接 UPDATE sp_case_config.preset_exams，覆盖为含 result 的 JSON 字符串。
- 无 DDL：preset_exams 已是 JSON 列，结构扩展在 JSON 内做。
- 可重跑幂等：每次运行都把 case1/case26 设为同一份金标准。
- 演示两病种跨科室复用：case1 心梗（ecg/lab/image 三卡全形态）、
  case26 胆囊结石（lab+image 多卡），验证 match_exams + 报告渲染链路。

执行：python scripts/seed_exam_results.py
"""
from __future__ import annotations

import asyncio
import json
import os
import pathlib

import aiomysql


CASES: dict[int, list[dict]] = {
    1: [
        {
            "name": "心电图",
            "aliases": ["ECG", "12导联心电图", "做个心电图", "心电图检查"],
            "cost": "50",
            "mark": "关键",
            "type": 1,
            "result": {
                "kind": "ecg",
                "conclusion": (
                    "窦性心律，心率78次/分；Ⅱ、Ⅲ、aVF 导联 ST 段弓背向上抬高 "
                    "0.2~0.4mV，伴 T 波高尖；Ⅰ、aVL 导联 ST 段轻度压低。"
                    "提示：急性 ST 段抬高型下壁心肌梗死（STEMI）。"
                ),
                "ecg": {"pattern": "st_elev_inferior", "rate": 78, "rhythm": "sinus"},
                "imageKeys": ["tb8_c95.jpeg"],
            },
        },
        {
            "name": "血浆肌钙蛋白I",
            "aliases": [
                "肌钙蛋白",
                "cTnI",
                "肌钙蛋白I",
                "心肌损伤标志物",
                "抽血查肌钙",
            ],
            "cost": "200",
            "mark": "关键",
            "type": 1,
            "result": {
                "kind": "lab",
                "conclusion": "肌钙蛋白I显著升高，符合急性心肌损伤",
                "table": [
                    {"item": "肌钙蛋白I(cTnI)", "value": "3.42", "unit": "ng/mL", "ref": "<0.04", "flag": "H"},
                    {"item": "肌酸激酶同工酶(CK-MB)", "value": "38", "unit": "U/L", "ref": "<25", "flag": "H"},
                    {"item": "肌红蛋白(Myo)", "value": "486", "unit": "ng/mL", "ref": "<110", "flag": "H"},
                ],
            },
        },
        {
            "name": "胸部CT血管造影",
            "aliases": ["胸部CT", "主动脉CT", "CTA", "夹层CT", "CT血管造影"],
            "cost": "800",
            "mark": None,
            "type": 0,
            "result": {
                "kind": "image",
                "conclusion": (
                    "主动脉全程未见夹层征象，未见肺动脉栓塞，冠脉走行区可见钙化。"
                    "排除主动脉夹层与急性 PTE。"
                ),
                "imageKeys": [],
            },
        },
    ],
    26: [
        {
            "name": "血常规",
            "aliases": ["血分析", "抽血验血常规", "血常规化验"],
            "cost": "30",
            "mark": None,
            "type": 0,
            "result": {
                "kind": "lab",
                "conclusion": "白细胞及分类基本正常范围，血红蛋白略低（轻度贫血倾向）",
                "table": [
                    {"item": "白细胞(WBC)", "value": "7.7", "unit": "×10⁹/L", "ref": "4.0-10.0", "flag": ""},
                    {"item": "中性粒细胞百分比(N%)", "value": "77.4", "unit": "%", "ref": "50-70", "flag": "H"},
                    {"item": "红细胞(RBC)", "value": "3.7", "unit": "×10¹²/L", "ref": "3.5-5.0", "flag": ""},
                    {"item": "血红蛋白(Hb)", "value": "118", "unit": "g/L", "ref": "115-150", "flag": ""},
                ],
            },
        },
        {
            "name": "肝功能",
            "aliases": ["肝功", "肝功检查", "肝功能检查"],
            "cost": "80",
            "mark": None,
            "type": 0,
            "result": {
                "kind": "lab",
                "conclusion": "ALT/AST/胆红素均在正常范围，肝功能未见异常",
                "table": [
                    {"item": "丙氨酸氨基转移酶(ALT)", "value": "28", "unit": "U/L", "ref": "7-40", "flag": ""},
                    {"item": "天门冬氨酸氨基转移酶(AST)", "value": "32", "unit": "U/L", "ref": "13-35", "flag": ""},
                    {"item": "总胆红素(TBIL)", "value": "14.6", "unit": "μmol/L", "ref": "3.4-20.5", "flag": ""},
                    {"item": "直接胆红素(DBIL)", "value": "4.2", "unit": "μmol/L", "ref": "0-6.8", "flag": ""},
                ],
            },
        },
        {
            "name": "腹部多普勒超声",
            "aliases": ["腹部B超", "腹部彩超", "腹部超声", "B超", "肝胆B超"],
            "cost": "120",
            "mark": "关键",
            "type": 1,
            "result": {
                "kind": "image",
                "conclusion": (
                    "胆囊大小约 6.7×4.8cm，壁厚约 0.2cm，囊内见一直径约 1.8cm "
                    "强回声团，后伴声影，随体位改变可移动。符合胆囊结石声像图表现。"
                ),
                "imageKeys": [],
            },
        },
        {
            "name": "上腹部CT",
            "aliases": ["腹部CT", "肝胆CT", "上腹CT"],
            "cost": "600",
            "mark": None,
            "type": 0,
            "result": {
                "kind": "image",
                "conclusion": (
                    "胆囊形态正常，壁不厚，囊内见高密度结石影，直径约 1.8cm。"
                    "肝内外胆管无扩张，未见胆总管结石。诊断：胆囊结石。"
                ),
                "imageKeys": [],
            },
        },
    ],
}


async def apply() -> None:
    # 数据库配置走环境变量，未设则走项目默认值（与 docker-compose 启动的 zhiyu-mysql 一致）
    host = os.getenv("MYSQL_HOST", "127.0.0.1")
    port = int(os.getenv("MYSQL_PORT", "3306"))
    user = os.getenv("MYSQL_USER", "root")
    password = os.getenv("MYSQL_PASSWORD", "root123456")
    db = os.getenv("MYSQL_DATABASE", "zhiyu_db")

    conn = await aiomysql.connect(host=host, port=port, user=user, password=password, db=db, charset="utf8mb4")
    try:
        async with conn.cursor() as cur:
            for case_id, items in CASES.items():
                payload = json.dumps(items, ensure_ascii=False)
                await cur.execute(
                    "UPDATE sp_case_config SET preset_exams = %s WHERE id = %s",
                    (payload, case_id),
                )
                print(f"case_id={case_id} updated {cur.rowcount} row, len={len(payload)}")
        await conn.commit()
    finally:
        conn.close()


if __name__ == "__main__":
    pathlib.Path(__file__).parent.resolve()
    asyncio.run(apply())