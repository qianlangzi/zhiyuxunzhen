package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.FieldFill;
import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 用户关键动作日志（P2-3 试用埋点）
 * 轻量 append-only 日志表，不做更新，仅记录 created_at。
 */
@Data
@TableName("user_action_log")
public class UserActionLog {

    @TableId(type = IdType.AUTO)
    private Long id;

    private Long userId;

    /** student / teacher */
    private String role;

    /** 动作编码：companion_open / learning_path_generate / ai_tutor_open ... */
    private String action;

    /** 动作描述/关键摘要 */
    private String detail;

    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdAt;
}
