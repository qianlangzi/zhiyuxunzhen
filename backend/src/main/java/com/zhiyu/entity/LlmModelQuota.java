package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 模型月度 Token 配额（V39）
 * 与 llm_token_usage.model 对应，用于管理端超额告警。
 */
@Data
@TableName("llm_model_quota")
public class LlmModelQuota {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 模型标识，与 llm_token_usage.model 对齐 */
    private String model;

    /** 月度 token 上限，0 表示不限制 */
    private Long monthlyQuota;

    /** 告警阈值百分比 */
    private Integer warnPercent;

    /** 1 启用 0 停用 */
    private Integer status;

    private String remark;

    private LocalDateTime createdAt;

    private LocalDateTime updatedAt;
}
