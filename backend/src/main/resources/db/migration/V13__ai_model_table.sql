-- ============================================================
-- V13: AI 模型管理表（模型管理 · 参照 ccswitch 供应商管理模式）
-- ------------------------------------------------------------
-- 模型能力维度 capability 枚举（与 AI 中台 ModelRegistry 对齐）：
--   LLM                文本对话大模型（教师端/学生端所有问答、批阅、SP 配置等）
--   VISION             多模态读图大模型（影像/检验分析、多媒体文档图述）
--   EMBEDDING          纯文本向量模型（旧 OpenAI 兼容协议，降级用）
--   EMBEDDING_MULTI    多模态向量模型（DashScope Qwen3-VL-Embedding，教材向量化用）
-- 每个能力下同一时刻至多一个 is_active=1 的模型；status 控制启用/停用。
-- api_key 明文存库但管理端 VO 脱敏展示、写审计日志时脱敏，内部接口按内网信任返回明文。
-- ============================================================

CREATE TABLE IF NOT EXISTS ai_model (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '主键',
    name VARCHAR(100) NOT NULL COMMENT '模型显示名称',
    provider VARCHAR(100) DEFAULT NULL COMMENT '供应商/来源说明',
    capability VARCHAR(30) NOT NULL COMMENT '能力类型: LLM/VISION/EMBEDDING/EMBEDDING_MULTI',
    base_url VARCHAR(255) NOT NULL COMMENT 'OpenAI 兼容接口地址',
    api_key VARCHAR(512) DEFAULT NULL COMMENT 'API 密钥（明文存库，VO 脱敏）',
    model VARCHAR(128) NOT NULL COMMENT '实际模型名（如 deepseek-chat / qwen3-omni-flash / bge-m3）',
    dimension INT DEFAULT NULL COMMENT '向量维度（EMBEDDING 系用，如 1024）',
    timeout_seconds INT NOT NULL DEFAULT 30 COMMENT '请求超时（秒）',
    max_tokens INT DEFAULT NULL COMMENT '最大生成 tokens（LLM/VISION 用）',
    temperature DECIMAL(3,1) DEFAULT NULL COMMENT '温度（LLM 用，0-2）',
    is_active TINYINT NOT NULL DEFAULT 0 COMMENT '当前激活(1)/备用(0)，每能力至多一个激活',
    status TINYINT NOT NULL DEFAULT 1 COMMENT '状态: 0停用 1启用',
    description VARCHAR(255) DEFAULT NULL COMMENT '备注',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (id),
    KEY idx_capability_status (capability, status),
    KEY idx_capability_active (capability, is_active)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = 'AI 模型供应商配置';