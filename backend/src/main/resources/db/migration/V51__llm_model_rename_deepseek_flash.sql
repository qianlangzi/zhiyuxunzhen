-- LLM 模型名对齐 DeepSeek 官方新命名（deepseek-v4-flash -> deepseek-flash）
--
-- 背景：DeepSeek 官方 2026-09-10 起将模型名统一为 `deepseek-flash`
--       （= DeepSeek-V4.1-Flash，1M 上下文 / 支持 Vision）。旧名
--       `deepseek-v4-flash`、`deepseek-v4-flash-vision-exp` 仍被接受，但对应
--       模型已下线，请求由 V4.1-Flash 提供服务并按 Flash 价格计费。
--       `deepseek-v4-pro` 将于 2026-09-14 12:00（北京时间）起同样路由到 V4.1 Flash。
--
-- 影响面：本项目线上实际已在由 V4.1-Flash 服务（实测响应 model 字段回
--         `deepseek-flash`），本次更名属账面对齐，不改变模型能力，也不改
--         base_url / api_key / 激活状态 —— 因此**无业务行为变更、可随时回退**。
--
-- 仅动 capability='LLM' 的行：VISION / EMBEDDING / EMBEDDING_MULTI 不受影响。
-- VISION 是否切换到 DeepSeek 属独立决策（切了需补 VISION_ALLOWED_HOSTS 白名单），
-- 此处不做变更，由管理端「模型管理」按需操作。
--
-- 幂等：WHERE 限定旧值，重复执行第二次无匹配行，不会反复改写。
UPDATE ai_model
SET model = 'deepseek-flash',
    name  = 'DeepSeek V4.1 Flash'
WHERE capability = 'LLM'
  AND model = 'deepseek-v4-flash';
