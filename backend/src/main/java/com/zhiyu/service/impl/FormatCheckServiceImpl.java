package com.zhiyu.service.impl;

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
 * 解析大病历正文中的段落标题（标题后跟全角或半角冒号），提取各段落内容后校验：
 * 必填段落齐全、主诉字数 ≤ 20、过敏史不允许空白。
 */
@Slf4j
@Service
public class FormatCheckServiceImpl implements FormatCheckService {

    /** 必填段落（顺序即文档常规顺序） */
    private static final List<String> REQUIRED_SECTIONS =
            List.of("主诉", "现病史", "既往史", "过敏史", "体格检查", "辅助检查", "初步诊断");

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

        Map<String, String> sections = parseSections(medicalRecordText);
        List<String> errors = new ArrayList<>();

        // 1. 必填段落齐全
        for (String section : REQUIRED_SECTIONS) {
            String content = sections.get(section);
            if (content == null || content.isBlank()) {
                errors.add("缺少必填段落：" + section);
            }
        }

        // 2. 主诉字数 ≤ 20
        String chief = sections.get("主诉");
        if (chief != null && !chief.isBlank() && chief.length() > 20) {
            errors.add("主诉字数不能超过20字（当前" + chief.length() + "字）");
        }

        // 3. 过敏史不允许空白
        String allergy = sections.get("过敏史");
        if (allergy != null && allergy.isBlank()) {
            errors.add("过敏史不能为空白");
        }

        boolean passed = errors.isEmpty();
        return FormatCheckResultVO.builder()
                .passed(passed)
                .errors(passed ? List.of() : errors)
                .checkedAt(checkedAt)
                .build();
    }

    /**
     * 按段落标题切分正文，返回 段落名 -> 内容。
     * 段落标题识别：段落名后紧跟全角"："或半角":"。
     */
    private Map<String, String> parseSections(String text) {
        List<SectionHit> hits = new ArrayList<>();
        for (String name : REQUIRED_SECTIONS) {
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
