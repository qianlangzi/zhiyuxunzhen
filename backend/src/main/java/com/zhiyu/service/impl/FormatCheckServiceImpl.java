package com.zhiyu.service.impl;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.service.FormatCheckService;
import com.zhiyu.vo.FormatCheckResultVO;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 大病历格式盾牌校验实现（PRD 5.3）
 * <p>
 * 解析大病历正文中的段落标题（标题后跟全角或半角冒号），提取各段落内容后校验。
 * 默认规则：必填段落齐全、主诉字数 ≤ 20、过敏史不允许空白。
 * <p>
 * 支持作业级自定义规则 JSON（formatRuleJson），可覆盖默认值：
 * <pre>
 * {
 *   "requiredSections": ["主诉", "现病史", "既往史", "过敏史", "体格检查", "辅助检查", "初步诊断"],
 *   "maxChiefLength": 20,
 *   "allergyRequired": true,
 *   "minWordCount": 100
 * }
 * </pre>
 * 解析失败或字段缺失时回退默认规则，保证不阻断提交流程。
 */
@Slf4j
@Service
public class FormatCheckServiceImpl implements FormatCheckService {

    /** 必填段落（顺序即文档常规顺序） */
    private static final List<String> DEFAULT_REQUIRED_SECTIONS =
            List.of("主诉", "现病史", "既往史", "过敏史", "体格检查", "辅助检查", "初步诊断");

    /** 主诉最大字数（默认） */
    private static final int DEFAULT_MAX_CHIEF_LENGTH = 20;

    /** 是否要求过敏史非空（默认） */
    private static final boolean DEFAULT_ALLERGY_REQUIRED = true;

    private static final int DEFAULT_MIN_WORD_COUNT = 0;

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Override
    public FormatCheckResultVO check(String medicalRecordText, String formatRuleJson) {
        LocalDateTime checkedAt = LocalDateTime.now();
        if (medicalRecordText == null || medicalRecordText.isBlank()) {
            return FormatCheckResultVO.builder()
                    .passed(false)
                    .errors(List.of("大病历正文不能为空"))
                    .checkedAt(checkedAt)
                    .build();
        }

        RuleSet rules = parseRules(formatRuleJson);
        Map<String, String> sections = parseSections(medicalRecordText, rules.requiredSections);
        List<String> errors = new ArrayList<>();

        // 1. 必填段落齐全
        for (String section : rules.requiredSections) {
            String content = sections.get(section);
            if (content == null || content.isBlank()) {
                errors.add("缺少必填段落：" + section);
            }
        }

        // 2. 主诉字数限制
        if (rules.maxChiefLength > 0) {
            String chief = sections.get("主诉");
            if (chief != null && !chief.isBlank() && chief.length() > rules.maxChiefLength) {
                errors.add("主诉字数不能超过" + rules.maxChiefLength + "字（当前" + chief.length() + "字）");
            }
        }

        // 3. 过敏史不允许空白
        if (rules.allergyRequired) {
            String allergy = sections.get("过敏史");
            if (allergy != null && allergy.isBlank()) {
                errors.add("过敏史不能为空白");
            }
        }

        // 4. 正文总字数下限（自定义规则）
        if (rules.minWordCount > 0) {
            int wordCount = medicalRecordText.replaceAll("\\s", "").length();
            if (wordCount < rules.minWordCount) {
                errors.add("大病历总字数不能少于" + rules.minWordCount + "字（当前" + wordCount + "字）");
            }
        }

        boolean passed = errors.isEmpty();
        return FormatCheckResultVO.builder()
                .passed(passed)
                .errors(passed ? List.of() : errors)
                .checkedAt(checkedAt)
                .build();
    }

    /** 解析作业级规则 JSON；缺省/非法时使用默认规则 */
    private RuleSet parseRules(String formatRuleJson) {
        RuleSet rules = new RuleSet(
                DEFAULT_REQUIRED_SECTIONS,
                DEFAULT_MAX_CHIEF_LENGTH,
                DEFAULT_ALLERGY_REQUIRED,
                DEFAULT_MIN_WORD_COUNT);
        if (formatRuleJson == null || formatRuleJson.isBlank()) {
            return rules;
        }
        try {
            Map<String, Object> map = objectMapper.readValue(formatRuleJson,
                    new TypeReference<Map<String, Object>>() {});
            Object sectionsRaw = map.get("requiredSections");
            if (sectionsRaw instanceof List<?> list && !list.isEmpty()) {
                List<String> sections = new ArrayList<>();
                for (Object item : list) {
                    if (item != null && !item.toString().isBlank()) {
                        sections.add(item.toString().trim());
                    }
                }
                if (!sections.isEmpty()) {
                    rules = new RuleSet(sections, rules.maxChiefLength,
                            rules.allergyRequired, rules.minWordCount);
                }
            }
            if (map.get("maxChiefLength") instanceof Number n && n.intValue() > 0) {
                rules = new RuleSet(rules.requiredSections, n.intValue(),
                        rules.allergyRequired, rules.minWordCount);
            }
            if (map.get("allergyRequired") instanceof Boolean b) {
                rules = new RuleSet(rules.requiredSections, rules.maxChiefLength,
                        b, rules.minWordCount);
            }
            if (map.get("minWordCount") instanceof Number n && n.intValue() > 0) {
                rules = new RuleSet(rules.requiredSections, rules.maxChiefLength,
                        rules.allergyRequired, n.intValue());
            }
        } catch (Exception e) {
            log.warn("解析格式规则 JSON 失败，使用默认规则: {}", formatRuleJson, e);
        }
        return rules;
    }

    /**
     * 按段落标题切分正文，返回 段落名 -> 内容。
     * 段落标题识别：段落名后紧跟全角"："或半角":"。
     */
    private Map<String, String> parseSections(String text, List<String> sectionNames) {
        List<SectionHit> hits = new ArrayList<>();
        for (String name : sectionNames) {
            int idx = findHeader(text, name);
            if (idx >= 0) {
                hits.add(new SectionHit(name, idx));
            }
        }
        hits.sort(Comparator.comparingInt(h -> h.start));

        Map<String, String> result = new LinkedHashMap<>();
        for (int i = 0; i < hits.size(); i++) {
            SectionHit cur = hits.get(i);
            int contentStart = skipColon(text, cur.start + cur.name.length());
            int contentEnd = (i + 1 < hits.size()) ? hits.get(i + 1).start : text.length();
            String content = text.substring(contentStart, contentEnd).trim();
            result.put(cur.name, content);
        }
        return result;
    }

    /** 查找段落名后紧跟冒号的位置，返回段落名起始下标，未找到返回 -1 */
    private int findHeader(String text, String name) {
        int from = 0;
        while (true) {
            int idx = text.indexOf(name, from);
            if (idx < 0) {
                return -1;
            }
            int after = idx + name.length();
            if (after < text.length()) {
                char c = text.charAt(after);
                if (c == '：' || c == ':') {
                    return idx;
                }
            }
            from = idx + 1;
        }
    }

    /** 跳过当前位置的全角/半角冒号 */
    private int skipColon(String text, int pos) {
        if (pos < text.length()) {
            char c = text.charAt(pos);
            if (c == '：' || c == ':') {
                return pos + 1;
            }
        }
        return pos;
    }

    /** 规则集 */
    private record RuleSet(List<String> requiredSections, int maxChiefLength,
                           boolean allergyRequired, int minWordCount) {}

    /** 段落命中位置 */
    private static class SectionHit {
        final String name;
        final int start;

        SectionHit(String name, int start) {
            this.name = name;
            this.start = start;
        }
    }
}
