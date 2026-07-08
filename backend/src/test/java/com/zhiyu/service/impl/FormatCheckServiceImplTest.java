package com.zhiyu.service.impl;

import com.zhiyu.vo.FormatCheckResultVO;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 大病历格式盾牌校验 — 单元测试（纯逻辑，无 Spring 依赖）
 */
@DisplayName("大病历格式校验 FormatCheckServiceImpl")
class FormatCheckServiceImplTest {

    private final FormatCheckServiceImpl service = new FormatCheckServiceImpl();

    /** 构造一份 7 段齐全、主诉 ≤20 字、过敏史非空的大病历 */
    private String validRecord() {
        return """
                主诉：头痛三天
                现病史：患者三天前无明显诱因出现头痛，呈持续性胀痛
                既往史：高血压病史五年，否认糖尿病
                过敏史：青霉素
                体格检查：神志清楚，双侧瞳孔等大等圆
                辅助检查：血常规正常，头颅CT未见异常
                初步诊断：偏头痛
                """;
    }

    @Test
    @DisplayName("正常大病历（7段齐全、主诉≤20字、过敏史非空）→ passed=true")
    void should_pass_when_all_sections_valid() {
        FormatCheckResultVO result = service.check(validRecord(), null);

        assertThat(result.getPassed()).isTrue();
        assertThat(result.getErrors()).isEmpty();
        assertThat(result.getCheckedAt()).isNotNull();
    }

    @Test
    @DisplayName("缺少必填段落（少主诉段）→ passed=false, errors 含缺少必填段落：主诉")
    void should_fail_when_missing_required_section() {
        String text = """
                现病史：患者三天前出现头痛
                既往史：高血压病史五年
                过敏史：青霉素
                体格检查：神志清楚
                辅助检查：血常规正常
                初步诊断：偏头痛
                """;

        FormatCheckResultVO result = service.check(text, null);

        assertThat(result.getPassed()).isFalse();
        assertThat(result.getErrors()).anySatisfy(err ->
                assertThat(err).contains("主诉"));
    }

    @Test
    @DisplayName("主诉超字数（21字）→ passed=false, errors 含'主诉字数不能超过20字'")
    void should_fail_when_chief_complaint_exceeds_20_chars() {
        // 构造 21 字的主诉
        String longChief = "一二三四五六七八九十一二三四五六七八九十一";
        assertThat(longChief.length()).isEqualTo(21);

        String text = "主诉：" + longChief + "\n"
                + "现病史：患者三天前出现头痛\n"
                + "既往史：高血压病史五年\n"
                + "过敏史：青霉素\n"
                + "体格检查：神志清楚\n"
                + "辅助检查：血常规正常\n"
                + "初步诊断：偏头痛\n";

        FormatCheckResultVO result = service.check(text, null);

        assertThat(result.getPassed()).isFalse();
        assertThat(result.getErrors()).anySatisfy(err ->
                assertThat(err).contains("主诉字数不能超过20字").contains("21"));
    }

    @Test
    @DisplayName("过敏史为空白 → passed=false, errors 含'过敏史不能为空白'")
    void should_fail_when_allergy_is_blank() {
        String text = """
                主诉：头痛三天
                现病史：患者三天前出现头痛
                既往史：高血压病史五年
                过敏史：
                体格检查：神志清楚
                辅助检查：血常规正常
                初步诊断：偏头痛
                """;

        FormatCheckResultVO result = service.check(text, null);

        assertThat(result.getPassed()).isFalse();
        assertThat(result.getErrors()).anySatisfy(err ->
                assertThat(err).contains("过敏史不能为空白"));
    }

    @Test
    @DisplayName("全角冒号识别（'主诉：xx'）")
    void should_recognize_full_width_colon() {
        String text = validRecord(); // 使用全角冒号

        FormatCheckResultVO result = service.check(text, null);

        assertThat(result.getPassed()).isTrue();
    }

    @Test
    @DisplayName("半角冒号识别（'主诉:xx'）")
    void should_recognize_half_width_colon() {
        String text = """
                主诉:头痛三天
                现病史:患者三天前出现头痛
                既往史:高血压病史五年
                过敏史:青霉素
                体格检查:神志清楚
                辅助检查:血常规正常
                初步诊断:偏头痛
                """;

        FormatCheckResultVO result = service.check(text, null);

        assertThat(result.getPassed()).isTrue();
    }

    @Test
    @DisplayName("空文本 → passed=false, errors 含'大病历正文不能为空'")
    void should_fail_when_text_is_blank() {
        FormatCheckResultVO result = service.check("   ", null);

        assertThat(result.getPassed()).isFalse();
        assertThat(result.getErrors()).containsExactly("大病历正文不能为空");
    }

    @Test
    @DisplayName("null 文本 → passed=false, errors 含'大病历正文不能为空'")
    void should_fail_when_text_is_null() {
        FormatCheckResultVO result = service.check(null, null);

        assertThat(result.getPassed()).isFalse();
        assertThat(result.getErrors()).containsExactly("大病历正文不能为空");
    }

    @Test
    @DisplayName("多段顺序错乱也能识别")
    void should_recognize_sections_in_any_order() {
        // 段落顺序完全打乱
        String text = """
                初步诊断：偏头痛
                过敏史：青霉素
                体格检查：神志清楚
                主诉：头痛三天
                辅助检查：血常规正常
                现病史：患者三天前出现头痛
                既往史：高血压病史五年
                """;

        FormatCheckResultVO result = service.check(text, null);

        assertThat(result.getPassed()).isTrue();
        assertThat(result.getErrors()).isEmpty();
    }
}
