package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.util.List;

@Data
@Builder
public class AiSessionContextVO {
    private Long sessionId;
    private Long studentId;
    private Long caseId;
    private String title;
    private String patientProfile;
    private String hiddenDisease;
    private String standardPathJson;
    private String presetExams;
    private List<Message> messages;

    @Data
    @Builder
    public static class Message {
        private String sender;
        private String content;
        private String citations;
    }
}
