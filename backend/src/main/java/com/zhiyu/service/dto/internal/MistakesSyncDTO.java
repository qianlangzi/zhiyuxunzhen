package com.zhiyu.service.dto.internal;

import lombok.Data;

import java.util.List;

/**
 * 错题本同步回调（PRD 9.4）
 * FastAPI 分析完成后批量同步学生错题
 */
@Data
public class MistakesSyncDTO {

    private List<MistakeItem> mistakes;

    @Data
    public static class MistakeItem {
        private Long studentId;
        private Long sessionId;
        private Long caseId;

        /** diagnosis / history / exam / record / communication */
        private String mistakeType;

        private String knowledgeTag;
        private String studentAnswer;
        private String standardAnswer;

        /** 关键证据和脱轨节点 JSON */
        private String evidenceJson;
    }
}
