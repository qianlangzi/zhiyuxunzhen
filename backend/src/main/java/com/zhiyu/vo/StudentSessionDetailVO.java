package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

/** 学生端可见的会话详情，不包含标准答案、隐藏疾病等病例答案。 */
@Data
@Builder
public class StudentSessionDetailVO {
    private Long sessionId;
    private Long caseId;
    private Integer status;
    private LocalDateTime createdAt;
    private List<Message> messages;

    @Data
    @Builder
    public static class Message {
        private String sender;
        private String content;
        private LocalDateTime createdAt;
    }
}
