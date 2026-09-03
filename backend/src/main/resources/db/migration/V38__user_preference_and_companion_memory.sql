-- AI 学伴用户偏好（语气档位 + 记忆开关）
-- 服务端持久化，多端一致；upsert 语义，不提供删除（同一 student_id + pref_key 唯一）
CREATE TABLE IF NOT EXISTS user_preference (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    student_id BIGINT NOT NULL COMMENT '学生用户ID',
    pref_key VARCHAR(64) NOT NULL COMMENT '偏好键：ai_tone / ai_memory_enabled',
    pref_value VARCHAR(512) NOT NULL COMMENT '偏好值',
    is_active TINYINT NOT NULL DEFAULT 1 COMMENT '是否生效 1是 0否',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uk_student_pref_key (student_id, pref_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='用户偏好表（AI学伴语气与记忆开关）';

-- AI 学伴长期记忆（抽取式：AI 对话后抽取"值得记住的事实"，对话前召回注入）
CREATE TABLE IF NOT EXISTS companion_memory (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    student_id BIGINT NOT NULL COMMENT '学生用户ID',
    fact_type VARCHAR(32) NOT NULL DEFAULT 'fact' COMMENT '记忆类型：fact/profile/goal/preference/learning',
    content VARCHAR(500) NOT NULL COMMENT '记忆内容',
    source_session_id BIGINT DEFAULT NULL COMMENT '来源会话ID（companion_conversation.id，可为空）',
    deleted TINYINT NOT NULL DEFAULT 0 COMMENT '逻辑删除 0否 1是',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_student_created (student_id, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='AI学伴长期记忆表';
