package com.zhiyu.service.dto.internal;

import lombok.Data;

import java.math.BigDecimal;
import java.util.List;

/**
 * 薄弱知识点同步回调（PRD 9.4）
 * FastAPI 分析完成后 upsert 学生薄弱知识点
 */
@Data
public class WeaknessSyncDTO {

    private List<WeaknessItem> weaknessList;

    @Data
    public static class WeaknessItem {
        private Long studentId;
        private String knowledgeTag;

        /** 掌握度 0.00 ~ 1.00 */
        private BigDecimal weaknessScore;

        private Integer evidenceCount;

        /** 推荐路径 JSON */
        private String recommendedPathJson;
    }
}
