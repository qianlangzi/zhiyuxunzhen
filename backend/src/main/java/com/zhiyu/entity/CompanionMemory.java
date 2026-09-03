package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

/**
 * AI 学伴长期记忆（抽取式：AI 对话后抽取事实入库，对话前召回注入）
 * 区别于 SP（标准病人）链路，仅 AI 学伴使用。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("companion_memory")
public class CompanionMemory extends BaseEntity {

    /** 学生用户ID */
    private Long studentId;

    /** 记忆类型：fact / profile / goal / preference / learning */
    private String factType;

    /** 记忆内容 */
    private String content;

    /** 来源会话ID（companion_conversation.id，可为空） */
    private Long sourceSessionId;

    /** 逻辑删除 0否 1是 */
    private Integer deleted;
}
