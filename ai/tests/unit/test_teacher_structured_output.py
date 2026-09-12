"""教师端 AI 结构化输出的回归测试

覆盖 2026-09-12 线上故障的两条根因：
1. 模型把 age 输出成数字（58 而非 "58"）→ Pydantic 报 string_type →
   教师端 toast「输出校验失败: Input should be a valid string」；
2. 输出被 max_tokens 截断且尾部停在字段名/冒号/尾随逗号上 →
   旧修复逻辑补出非法 JSON → 误报「模型输出中未找到有效的 JSON」。
"""
from app.models.teacher import (
    CaseDraftResult,
    MaterialAdviceResult,
    QualityResult,
)
from app.services.structured_output import extract_json

import json

import pytest
from pydantic import ValidationError


# ---------- 根因 1：类型漂移（数字 → 字符串字段） ----------

def test_case_draft_accepts_numeric_str_fields():
    """age 为数字、fullMark 带单位、knowledgeTags 被压成字符串，都应被归一而非报错"""
    model = CaseDraftResult.model_validate({
        "patientProfile": "58岁男性退休矿工",
        "hiddenDisease": "急性ST段抬高型心肌梗死（下壁）",
        "age": 58,
        "scoringPoints": [{"label": "心电图判读", "fullMark": "10分", "criteria": "识别ST抬高"}],
        "knowledgeTags": "急性心肌梗死、冠心病鉴别诊断",
        "personality": "焦虑、急躁",
        "citations": [{"book_name": "内科学", "page_number": "P123"}],
    })

    assert model.age == "58"          # 数字 → 字符串（曾触发 string_type）
    assert model.scoringPoints[0].fullMark == 10
    assert model.knowledgeTags == ["急性心肌梗死", "冠心病鉴别诊断"]
    assert model.personality == ["焦虑", "急躁"]
    assert model.citations[0].page_number == 123


def test_case_draft_keeps_float_age_with_decimal():
    """58.5 不能被截成 58"""
    model = CaseDraftResult.model_validate({
        "patientProfile": "p", "hiddenDisease": "d", "age": 58.5,
    })
    assert model.age == "58.5"


def test_material_advice_accepts_non_string_values():
    model = MaterialAdviceResult.model_validate({
        "suggestions": [{"item": 12, "kind": "image", "priority": "1"}],
        "summary": 2026,
    })
    assert model.suggestions[0].item == "12"
    assert model.suggestions[0].priority == 1
    assert model.summary == "2026"


def test_quality_result_accepts_chinese_bool():
    model = QualityResult.model_validate({
        "overallPass": "是",
        "checklist": [{"item": "诊断一致性", "passed": "否", "reason": "路径不匹配"}],
    })
    assert model.overallPass is True
    assert model.checklist[0].passed is False


# ---------- 根因 2：截断输出的 JSON 修复 ----------

def test_extract_json_recovers_truncated_field_name():
    """尾部停在下一个字段名上（真实故障形态：`..."presetExams`）"""
    raw = (
        '{"patientProfile": "58岁男性", "hiddenDisease": "急性心肌梗死",'
        ' "standardPath": ["问诊", "心电图"], "presetExams'
    )
    parsed = extract_json(raw)
    assert parsed is not None
    assert CaseDraftResult.model_validate_json(parsed).hiddenDisease == "急性心肌梗死"


def test_extract_json_recovers_truncated_key_colon():
    """尾部停在冒号后：`..."scoringPoints":`"""
    raw = '{"patientProfile": "58岁男性", "hiddenDisease": "心梗", "scoringPoints":'
    parsed = extract_json(raw)
    assert parsed is not None
    assert CaseDraftResult.model_validate_json(parsed).patientProfile == "58岁男性"


def test_extract_json_recovers_trailing_comma():
    """尾随逗号（模型高频产物）：{"a":1,}"""
    parsed = extract_json('{"patientProfile": "p", "hiddenDisease": "d",}')
    assert parsed is not None
    assert CaseDraftResult.model_validate_json(parsed).hiddenDisease == "d"


def test_extract_json_recovers_mid_string_truncation():
    """截断在字符串中间：补引号后闭合（缺的必填字段仍由 Pydantic 拦下）"""
    raw = '{"patientProfile": "58岁男性退休矿工，长期粉尘暴露'
    parsed = extract_json(raw)
    assert parsed is not None
    assert "58岁男性退休矿工" in json.loads(parsed)["patientProfile"]
    # 必填字段缺失不进模型，避免把半截病例当完整草稿落库
    with pytest.raises(ValidationError):
        CaseDraftResult.model_validate(json.loads(parsed))


def test_extract_json_still_rejects_plain_text():
    """纯文本（模型没输出 JSON 结构）必须仍然判失败，不能伪造结果"""
    assert extract_json("抱歉，教材依据不足，无法生成病例草稿。") is None
    assert extract_json("") is None
