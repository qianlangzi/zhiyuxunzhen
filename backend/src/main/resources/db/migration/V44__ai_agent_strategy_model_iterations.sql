-- ============================================================
-- V20: ai_agent 增加执行策略 / 模型 / 最大迭代轮数字段
-- ------------------------------------------------------------
-- 与 AI 中台 config_center AgentSpec 对齐：strategy(CODE/TOOL/LOOP)、
-- model(指定模型，空用全局)、max_iterations(TOOL/LOOP 最大循环轮数)。
-- 空值表示使用 AI 内置默认（CODE），向后兼容既有配置。
-- ============================================================
ALTER TABLE ai_agent
    ADD COLUMN strategy VARCHAR(16) DEFAULT NULL COMMENT '执行策略(可选 CODE/TOOL/LOOP，空=内置默认 CODE)',
    ADD COLUMN model VARCHAR(128) DEFAULT NULL COMMENT '指定模型(空用全局默认)',
    ADD COLUMN max_iterations INT DEFAULT NULL COMMENT 'TOOL/LOOP 策略最大循环轮数(空用默认)';