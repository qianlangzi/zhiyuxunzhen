package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.util.List;

/**
 * Excel 批量导入学生账号结果（PRD 4.14）
 */
@Data
@Builder
public class ImportResultVO {

    private Integer successCount;

    private Integer failCount;

    private List<ImportFailure> failures;

    /**
     * 导入失败明细
     */
    @Data
    @Builder
    public static class ImportFailure {
        /** Excel 行号（从1开始，含表头） */
        private Integer row;
        private String username;
        private String reason;
    }
}
