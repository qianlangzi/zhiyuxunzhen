-- ============================================================
-- V33: AI 学伴会话历史（P1-2 学习陪伴 · 会话历史管理）
-- ------------------------------------------------------------
-- companion_conversation / companion_message：
--   与 chat_session（问诊会话）解耦——学伴=陪伴闲聊，不承载评分/病例字段。
--   列名采用 created_at/updated_at 与既有表（student_goal 等）及 BaseEntity
--   审计字段保持一致，便于 MyBatis-Plus 自动填充。
-- ============================================================

CREATE TABLE IF NOT EXISTS companion_conversation (
    id            BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
    student_id    BIGINT       NOT NULL COMMENT '学生ID',
    title         VARCHAR(100) NOT NULL DEFAULT '新对话' COMMENT '会话标题（首条消息截断）',
    deleted       TINYINT      NOT NULL DEFAULT 0 COMMENT '逻辑删除 0否 1是',
    created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_student_time (student_id, created_at, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI学伴会话';

CREATE TABLE IF NOT EXISTS companion_message (
    id             BIGINT       NOT NULL AUTO_INCREMENT COMMENT '主键',
    conversation_id BIGINT      NOT NULL COMMENT '会话ID',
    sender         VARCHAR(16)  NOT NULL COMMENT 'user/assistant',
    content        TEXT         NOT NULL COMMENT '文本内容',
    image_url      TEXT         NULL COMMENT '图片(HTTP URL 或 data URL)',
    created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_conversation (conversation_id, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI学伴消息';