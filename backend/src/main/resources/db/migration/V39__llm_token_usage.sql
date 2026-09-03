-- ============================================================
-- V39: 大模型 Token 用量流水与配额（管理端「模型管理 → Token 管理」）
-- ------------------------------------------------------------
-- 背景：AI 中台 llm_client 此前已统计 total_tokens，但仅写入日志，
--       既未落库也未回传后端，管理端无法观测消耗。
--
-- 采集链路（本迁移配套的改动）：
--   ai/app/services/llm_client.py 在 chat()/stream() 出口统计 token 后，
--   异步 POST /api/internal/token-usage/report（X-Internal-Token 鉴权），
--   由 TokenUsageService 落库。改一处即覆盖全部 Agent 调用，含流式。
--
-- 表职责：
--   llm_token_usage  每次 LLM 调用一行明细流水（只增不改）
--   llm_model_quota  按模型的月度配额与告警阈值（可维护）
--
-- 只增不删：与既有迁移一致，禁止 DROP/TRUNCATE。
-- ============================================================

CREATE TABLE IF NOT EXISTS llm_token_usage (
    id                BIGINT AUTO_INCREMENT PRIMARY KEY,
    trace_id          VARCHAR(64)  NULL
                      COMMENT '链路追踪ID，与 AI 中台日志对账用',
    scene             VARCHAR(64)  NOT NULL DEFAULT 'unknown'
                      COMMENT '调用场景:chat/review/lesson/case/companion/mistake/paper/evaluate 等',
    capability        VARCHAR(32)  NOT NULL DEFAULT 'LLM'
                      COMMENT 'AI能力:LLM/VISION/EMBEDDING/EMBEDDING_MULTI',
    model             VARCHAR(128) NOT NULL DEFAULT ''
                      COMMENT '模型标识（脱敏，不含密钥）',
    prompt_tokens     INT          NOT NULL DEFAULT 0
                      COMMENT '输入token',
    completion_tokens INT          NOT NULL DEFAULT 0
                      COMMENT '输出token',
    total_tokens      INT          NOT NULL DEFAULT 0
                      COMMENT '总token = 输入 + 输出',
    latency_ms        INT          NOT NULL DEFAULT 0
                      COMMENT '本次调用耗时（毫秒）',
    student_id        BIGINT       NULL
                      COMMENT '关联学生（可空，后台任务无归属）',
    session_id        BIGINT       NULL
                      COMMENT '关联问诊会话（可空）',
    success           TINYINT      NOT NULL DEFAULT 1
                      COMMENT '是否成功:1成功 0失败（失败调用也可能产生费用）',
    is_stream         TINYINT      NOT NULL DEFAULT 0
                      COMMENT '是否流式调用:1流式 0同步',
    created_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_token_created (created_at),
    KEY idx_token_model_created (model, created_at),
    KEY idx_token_scene_created (scene, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='大模型Token用量流水';

CREATE TABLE IF NOT EXISTS llm_model_quota (
    id            BIGINT AUTO_INCREMENT PRIMARY KEY,
    model         VARCHAR(128) NOT NULL
                  COMMENT '模型标识，与 llm_token_usage.model 对齐',
    monthly_quota BIGINT       NOT NULL DEFAULT 0
                  COMMENT '月度token上限，0表示不限制',
    warn_percent  INT          NOT NULL DEFAULT 80
                  COMMENT '告警阈值百分比，达到即触发管理端提示',
    status        TINYINT      NOT NULL DEFAULT 1
                  COMMENT '1启用 0停用',
    remark        VARCHAR(255) NULL
                  COMMENT '备注',
    created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_quota_model (model)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='模型月度Token配额';
