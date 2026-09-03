package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.util.List;

/**
 * Excel 批量导入学生账号结果（PRD 4.14）
 *
 * 成功列表含随机生成的临时密码，管理员需妥善分发并提醒学生首次登录后改密。
 */
@Data
@Builder
public class ImportResultVO {

    private Integer successCount;

    private Integer failCount;

    /** 成功导入的学生列表（含临时密码，仅管理员可见） */
    private List<ImportSuccess> successes;

    private List<ImportFailure> failures;

    /**
     * 导入成功明细（含临时密码）
     */
    @Data
    @Builder
    public static class ImportSuccess {
        /** Excel 行号（从1开始，含表头） */
        private Integer row;
        private String username;
        /** 随机生成的临时密码，需分发给学生 */
        private String tempPassword;
    }

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
