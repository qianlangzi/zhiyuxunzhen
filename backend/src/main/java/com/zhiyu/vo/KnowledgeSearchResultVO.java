package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.util.List;

/**
 * 教材知识库向量检索结果 VO（支持分科过滤）
 */
@Data
@Builder
public class KnowledgeSearchResultVO {
    private String query;
    private String subject;
    private List<CitationVO> citations;

    @Data
    @Builder
    public static class CitationVO {
        private String bookName;
        private String edition;
        private String chapter;
        private Integer pageNumber;
        private String chunkText;
        private String subject;
        private Double score;
        /** P1-4 影像检索：命中片段对应的教材原图 key（可为空） */
        private String imageKey;
    }
}
