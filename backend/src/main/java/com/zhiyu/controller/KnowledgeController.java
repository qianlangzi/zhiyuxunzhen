package com.zhiyu.controller;

import com.zhiyu.client.AiPlatformClient;
import com.zhiyu.common.R;
import com.zhiyu.vo.KnowledgeSearchResultVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * 教材知识库向量检索接口（支持分科过滤）
 */
@Slf4j
@Tag(name = "知识库检索")
@RestController
@RequestMapping("/api/v1/knowledge")
@RequiredArgsConstructor
public class KnowledgeController {

    private final AiPlatformClient aiPlatformClient;

    @Operation(summary = "向量检索教材知识库（支持学科过滤和多种检索策略）")
    @GetMapping("/search")
    public R<KnowledgeSearchResultVO> search(
            @RequestParam String query,
            @RequestParam(defaultValue = "5") int topK,
            @RequestParam(required = false) String subject,
            @RequestParam(required = false) String collection,
            @RequestParam(defaultValue = "dense") String strategy) {

        if (query == null || query.isBlank()) {
            return R.ok(KnowledgeSearchResultVO.builder()
                    .query("")
                    .subject(subject)
                    .citations(List.of())
                    .build());
        }

        Map<String, Object> aiResult = aiPlatformClient.searchKnowledge(
                query.trim(), topK, subject, collection, strategy);

        List<KnowledgeSearchResultVO.CitationVO> citations = new ArrayList<>();
        if (aiResult != null) {
            Object rawCitations = aiResult.get("citations");
            if (rawCitations instanceof List<?> list) {
                for (Object item : list) {
                    if (item instanceof Map<?, ?> m) {
                        citations.add(KnowledgeSearchResultVO.CitationVO.builder()
                                .bookName(str(m.get("book_name")))
                                .edition(str(m.get("edition")))
                                .chapter(str(m.get("chapter")))
                                .pageNumber(intVal(m.get("page_number")))
                                .chunkText(str(m.get("chunk_text")))
                                .subject(str(m.get("subject")))
                                .score(dblVal(m.get("score")))
                                .build());
                    }
                }
            }
        }

        return R.ok(KnowledgeSearchResultVO.builder()
                .query(query.trim())
                .subject(subject)
                .citations(citations)
                .build());
    }

    private static String str(Object o) {
        return o == null ? null : o.toString();
    }

    private static Integer intVal(Object o) {
        if (o == null) return null;
        if (o instanceof Number n) return n.intValue();
        try { return Integer.parseInt(o.toString()); } catch (Exception e) { return null; }
    }

    private static Double dblVal(Object o) {
        if (o == null) return null;
        if (o instanceof Number n) return n.doubleValue();
        try { return Double.parseDouble(o.toString()); } catch (Exception e) { return null; }
    }
}
