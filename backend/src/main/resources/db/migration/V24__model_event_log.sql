-- ============================================================
-- V24: AI 模型运行事件（管理端「最近模型事件」）
-- ------------------------------------------------------------
-- 由 AI 中台经 /api/internal/model-event/log 回调写入。
-- 与 audit_log 里零散的 model_event_* 审计记录不同，这里以结构化列
-- 持久化 trace_id / detail_json / capability / recovered 等字段，
-- 供管理端 /api/v1/admin/ai-config/model-events 做「AI 运行事件视图」。
-- 只增不删不改，按 created_at 倒序最近 N 条展示。
-- ============================================================

CREATE TABLE IF NOT EXISTS model_event_log (
    id           BIGINT AUTO_INCREMENT PRIMARY KEY,
    event_type   VARCHAR(32)  NOT NULL
                 COMMENT '事件类型:model_error/degradation/timeout/recovered/info',
    model_name   VARCHAR(64)  NULL
                 COMMENT '模型名称（脱敏，不含密钥）',
    capability   VARCHAR(32)  NULL
                 COMMENT 'AI 能力/来源:LLM/VISION/EMBEDDING/EMBEDDING_MULTI/fallback',
    error_message VARCHAR(1000) NULL
                 COMMENT '业务可读的原因文案（杜绝异常堆栈）',
    detail_json  JSON         NULL
                 COMMENT '结构化补充信息（不含密钥/Authorization）',
    trace_id     VARCHAR(64)  NULL
                 COMMENT '本次请求链路追踪ID，便于跨端对账',
    recovered    TINYINT      NOT NULL DEFAULT 0
                 COMMENT '是否恢复事件:1恢复 0异常/false',
    created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_model_event_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='AI 模型运行事件';