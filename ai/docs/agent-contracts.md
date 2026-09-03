# Agent Contracts

## 运行边界

FastAPI 不直接访问业务 MySQL。会话、用户、权限、评分和归档都通过 Spring Boot 内部接口完成。所有 Agent 必须接收 `trace_id`，不得把 JWT、内部 token 或原始患者隐私写入普通日志。

## SP Agent

- 输入：病例上下文、Spring Boot 返回的历史消息、可选 RAG citations。
- 输出：异步文本增量；由 `ChatWorkflow` 包装成 `message` SSE 事件。
- 失败：模型不可用时由 LLM 客户端按配置决定是否降级；生产环境关闭 synthetic fallback，调用方必须返回明确错误或 pending 状态。

## Mentor workflow

- 输入：同一轮会话上下文、SP 回复、当前思维树。
- 输出：`nodes`、`edges`、可选 `socrates_hint`。
- 约束：结构化结果解析失败只能返回空增量并记录告警，不得伪造评分。

## 非 Agent 工作流

Evaluator、Reviewer、Learning Path 和 Report 是规则/工作流，不允许自行决定权限或写业务数据；正式评分必须由 Spring Boot 接收并持久化。
