package com.zhiyu.controller;

import com.zhiyu.client.AiPlatformClient;
import com.zhiyu.common.R;
import com.zhiyu.vo.KnowledgeSearchResultVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
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
                                .imageKey(str(m.get("image_key")))
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

    /**
     * P1-4 以图搜图：多模态 embedding 检索教材影像知识库
     * POST /api/v1/knowledge/search-image
     */
    public record ImageSearchRequest(
            String imageBase64,
            String text,
            Integer topK,
            String subject) {
    }

    @Operation(summary = "以图搜图（影像检索 · P1-4 多模态医学知识库）")
    @PostMapping("/search-image")
    public R<KnowledgeSearchResultVO> searchByImage(@RequestBody ImageSearchRequest req) {
        if (req.imageBase64() == null || req.imageBase64().isBlank()) {
            return R.ok(KnowledgeSearchResultVO.builder()
                    .citations(List.of())
                    .build());
        }
        Map<String, Object> aiResult = aiPlatformClient.searchKnowledgeByImage(
                req.imageBase64(), req.text(), req.topK(), req.subject());

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
                                .imageKey(str(m.get("image_key")))
                                .build());
                    }
                }
            }
        }

        return R.ok(KnowledgeSearchResultVO.builder()
                .subject(req.subject())
                .citations(citations)
                .build());
    }

    /**
     * P1-4 获取教材原图字节（影像检索结果回显）
     * GET /api/v1/knowledge/images/{imageKey}
     */
    @Operation(summary = "获取教材图片（P1-4 影像检索回显原图）")
    @GetMapping("/images/{imageKey}")
    public ResponseEntity<byte[]> getImage(@PathVariable String imageKey) {
        byte[] bytes = aiPlatformClient.getKnowledgeImage(imageKey);
        if (bytes == null) {
            return ResponseEntity.notFound().build();
        }
        String ext = imageKey.contains(".")
                ? imageKey.substring(imageKey.lastIndexOf('.') + 1).toLowerCase()
                : "png";
        MediaType mediaType = "jpg".equals(ext) || "jpeg".equals(ext)
                ? MediaType.IMAGE_JPEG : MediaType.IMAGE_PNG;
        return ResponseEntity.ok().contentType(mediaType).body(bytes);
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
