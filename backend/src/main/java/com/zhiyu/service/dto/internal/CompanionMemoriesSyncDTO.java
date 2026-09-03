package com.zhiyu.service.dto.internal;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

import java.util.List;

/**
 * AI 学伴长期记忆同步回调
 * FastAPI 学伴对话结束后抽取"值得记住的事实"，批量回调写入 companion_memory。
 */
@Data
public class CompanionMemoriesSyncDTO {

    /** 学生用户ID */
    @NotNull(message = "studentId 不能为空")
    private Long studentId;

    /** 抽取出的记忆条目 */
    @Valid
    @Size(max = 20, message = "单次记忆同步不能超过 20 条")
    private List<MemoryFact> facts = List.of();

    @Data
    public static class MemoryFact {
        /** 记忆类型：fact / profile / goal / preference / learning */
        private String factType;

        /** 记忆内容 */
        @NotBlank(message = "记忆内容不能为空")
        @Size(max = 500, message = "单条记忆不能超过 500 字")
        private String content;

        /** 来源会话ID（companion_conversation.id，可为空） */
        private Long sourceSessionId;
    }
}
