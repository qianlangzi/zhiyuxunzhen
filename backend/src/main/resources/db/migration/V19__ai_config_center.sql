-- ============================================================
-- V19: AI 配置中心（提示词 · Agent 元参数 · RAG 运行参数 热更新）
-- ------------------------------------------------------------
-- 与 ai_model（模型连接参数）共同构成「AI 配置中心」：
--   模型管理      ai_model            连接参数（base_url/apiKey/model/温度/超时）
--   提示词管理    ai_prompt           各 Agent 的 system prompt（可热改，含版本）
--   Agent 管理    ai_agent            Agent 元参数（system prompt 引用 + 采样参数 + 工具开关）
--   RAG 运行参数  ai_runtime_config   检索/改写/迭代/图述等开关与阈值
-- 三张表遵循与 ai_model 相同的「每维度命名键下至多一个 is_active=1；status 控制启停」。
-- AI 中台周期调用内网接口热拉取「启用且激活」的最新值，覆盖运行期配置，无需重启服务。
-- ============================================================

-- ------------------------------------------------------------
-- 1. 提示词表（ai_prompt）
-- name 为逻辑键（如 sp / mentor / evaluator / lesson_design），同一 name 可有多个版本，
-- 同一 name 下至多一个 is_active=1。content 支持 {占位符} 用于注入运行时变量；
-- 未在表中配置的 name，AI 中台回退到内置模板，平滑迁移。
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ai_prompt (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
    name VARCHAR(64) NOT NULL COMMENT '提示词逻辑键（与 AI 中台内置模板名对齐）',
    version VARCHAR(32) DEFAULT 'v1' COMMENT '版本号（如 v1/v2）',
    title VARCHAR(128) NOT NULL COMMENT '显示名称（便于管理端识别）',
    description VARCHAR(255) DEFAULT NULL COMMENT '用途说明',
    content TEXT NOT NULL COMMENT '提示词正文（支持 {占位符}）',
    is_active TINYINT NOT NULL DEFAULT 0 COMMENT '当前激活(1)/备用(0)，同 name 至多一个激活',
    status TINYINT NOT NULL DEFAULT 1 COMMENT '状态: 0停用 1启用',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (id),
    KEY idx_prompt_name_active (name, is_active),
    KEY idx_prompt_name_status (name, status)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = 'AI 提示词管理（可热改 system prompt）';

-- ------------------------------------------------------------
-- 2. Agent 元参数表（ai_agent）
-- code 为逻辑键（如 sp / mentor / evaluator / reviewer / tutor / lesson_design ...），
-- prompt_name 引用其使用的 system prompt 逻辑键（默认同名）；temperature/max_tokens 可
-- 覆盖全局 LLM 的采样参数；tools_config 声明该 Agent 启用哪些工具（如 rag / vision）。
-- 执行编排逻辑仍在 AI 中台代码，本表只管理「行为参数」，符合元参数层边界。
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ai_agent (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
    code VARCHAR(64) NOT NULL COMMENT 'Agent 逻辑键（与 AI 中台 agent 代码名对齐）',
    name VARCHAR(128) NOT NULL COMMENT '显示名称',
    description VARCHAR(255) DEFAULT NULL COMMENT '职责说明',
    prompt_name VARCHAR(64) DEFAULT NULL COMMENT '引用的提示词逻辑键（默认同名）',
    -- prompt_override 非空时优先于 prompt_name 命中的提示词生效（直接作为该 Agent 的 system prompt）
    prompt_override VARCHAR(2048) DEFAULT NULL COMMENT 'system prompt 直接覆盖文本（可留空）',
    temperature DECIMAL(3,1) DEFAULT NULL COMMENT '采样温度覆盖（留空用全局）',
    max_tokens INT DEFAULT NULL COMMENT '最大生成 tokens 覆盖（留空用全局）',
    tools_config VARCHAR(255) DEFAULT NULL COMMENT '启用工具（rag/vision/...，逗号分隔）',
    is_active TINYINT NOT NULL DEFAULT 0 COMMENT '当前激活(1)/备用(0)，同 code 至多一个激活',
    status TINYINT NOT NULL DEFAULT 1 COMMENT '状态: 0停用 1启用',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (id),
    KEY idx_agent_code_active (code, is_active),
    KEY idx_agent_code_status (code, status)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = 'AI Agent 元参数管理（行为参数可热改）';

-- ------------------------------------------------------------
-- 3. RAG 运行参数表（ai_runtime_config）
-- 键值型配置：config_key 与 AI 中台 settings/I调用点 对齐，AI 中台热拉取后覆盖运行期值。
-- config_type 用于管理端渲染输入控件：number / switch / text / float。
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ai_runtime_config (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
    config_key VARCHAR(64) NOT NULL COMMENT '配置键（与 AI 中台运行参数对齐）',
    config_name VARCHAR(128) NOT NULL COMMENT '显示名称',
    description VARCHAR(255) DEFAULT NULL COMMENT '说明',
    config_type VARCHAR(16) NOT NULL DEFAULT 'number' COMMENT '类型: number/switch/float/text',
    value VARCHAR(255) NOT NULL COMMENT '当前生效值',
    default_value VARCHAR(255) DEFAULT NULL COMMENT '默认值（重置用）',
    `min` VARCHAR(32) DEFAULT NULL COMMENT '最小值（number/float 用）',
    `max` VARCHAR(32) DEFAULT NULL COMMENT '最大值（number/float 用）',
    step VARCHAR(32) DEFAULT NULL COMMENT '步长（number/float 用）',
    is_active TINYINT NOT NULL DEFAULT 1 COMMENT '是否参与下发(1)/冻结(0)',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (id),
    UNIQUE KEY uk_runtime_key (config_key)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = 'AI RAG 热运行参数（键值可热改）';

-- ------------------------------------------------------------
-- 种子数据：预置 RAG 运行参数（开箱即可热改，避免第一次使用为空）
-- ------------------------------------------------------------
INSERT INTO ai_runtime_config
    (config_key, config_name, description, config_type, value, default_value, `min`, `max`, step, is_active)
SELECT * FROM (
    SELECT 'citation_max_chars' AS config_key, '引文片段最大字符' AS config_name,
           'RAG 结果原文片段截断长度，过长易撑爆上下文、过短丢语义' AS description,
           'number' AS config_type, '2000' AS value, '2000' AS default_value,
           '200' AS `min`, '8000' AS `max`, '100' AS step, 1 AS is_active
    UNION ALL SELECT 'embed_concurrency', '入库向量并发数',
           '教材向量化批量 embedding 并发（DashScope 不支持批量，靠并发提速）',
           'number', '8', '8', '1', '32', '1', 1
    UNION ALL SELECT 'bm25_max_docs', 'BM25 索引规模上限',
           '稀疏检索在内存索引中的文档数上限，超过自动降级纯向量并告警',
           'number', '200000', '200000', '1000', '1000000', '1000', 1
    UNION ALL SELECT 'query_rewrite_enabled', '查询改写开关',
           '检索前用 LLM 口语转医学术语 + 多轮指代消解（需 LLM）',
           'switch', 'true', 'true', NULL, NULL, NULL, 1
    UNION ALL SELECT 'iterative_search_enabled', '自适应迭代检索开关',
           '向量 top1 分数低于阈值时用另一形态 query 重查一轮并融合',
           'switch', 'true', 'true', NULL, NULL, NULL, 1
    UNION ALL SELECT 'iterative_score_threshold', '迭代检索触发阈值',
           '向量通道 top1 余弦分低于该值时触发重查（0-1）',
           'float', '0.45', '0.45', '0', '1', '0.01', 1
    UNION ALL SELECT 'image_caption_enabled', '生成侧图述开关',
           '命中带图 chunk 时调用 VLM 生成图上文字描述并入生成上下文',
           'switch', 'true', 'true', NULL, NULL, NULL, 1
) AS seed
WHERE NOT EXISTS (SELECT 1 FROM ai_runtime_config);