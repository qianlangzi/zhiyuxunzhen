package com.zhiyu.service.dto.internal;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.List;

@Data
public class SessionMessageAppendDTO {
    @NotNull(message = "studentId 不能为空")
    private Long studentId;

    @Valid
    @NotEmpty(message = "messages 不能为空")
    private List<MessageItem> messages;

    @Data
    public static class MessageItem {
        @NotNull(message = "sender 不能为空")
        private String sender;
        @NotNull(message = "content 不能为空")
        private String content;
        private String citations;
    }
}
