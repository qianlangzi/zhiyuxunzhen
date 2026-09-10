-- 短信服务商运行时开关（管理端可热切换）
-- 背景：2025 年起运营商收紧短信实名制，第三方通道（聚合一类）可能被整体拒发
--       （表现为聚合 error_code=205404 / reason=发送失败：1036，实际是运营商网关拒绝码），
--       需要在管理端一键切换备用通道，而不必修改服务器 .env 并重启容器。
--
-- 取值优先级：sys_config('sms.provider') > 环境变量 SMS_PROVIDER。
-- 可选值：juhe（聚合数据，当前生效）/ aliyun_auth（阿里云短信认证，个人认证可用）/ off（关闭真实发送）。
--
-- 默认值取 juhe：与当前线上可用通道保持一致，**不改变现有发送行为**。
-- 阿里云短信认证作为热备用通道：等 ALIYUN_* 环境变量注入且管理端测试发送通过后，
-- 再在「管理端 → 系统配置 → 短信服务商」切到 aliyun_auth（即时生效）。
--
-- 幂等：已存在配置则不改动，保留运维在管理端的选择。
INSERT INTO sys_config (config_key, config_value, config_type)
SELECT 'sms.provider', 'juhe', 'SMS' FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM sys_config WHERE config_key = 'sms.provider');
