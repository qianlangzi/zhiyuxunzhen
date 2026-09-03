package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

/**
 * 用户偏好（AI 学伴语气 / 记忆开关，服务端持久化，多端一致）
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("user_preference")
public class UserPreference extends BaseEntity {

    /** 学生用户ID */
    private Long studentId;

    /** 偏好键：ai_tone / ai_memory_enabled */
    private String prefKey;

    /** 偏好值 */
    private String prefValue;

    /** 是否生效 1是 0否 */
    private Integer isActive;
}
