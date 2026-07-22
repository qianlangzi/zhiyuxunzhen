# Runbook

## 启动前检查

- 生产必须设置非默认 `JWT_SECRET`、`AI_INTERNAL_TOKEN`。
- `CORS_ALLOWED_ORIGINS` 和 `VISION_ALLOWED_HOSTS` 必须是明确列表。
- 生产关闭 `ENABLE_LLM_FALLBACK`、`ENABLE_MILVUS_FALLBACK`。
- 验证 Spring Boot callback、LLM、Embedding、Milvus 连通性。

## 健康检查

- `GET /health` 或 `/health/live`：只表示进程存活。
- `GET /health/ready`：检查 Redis/Milvus 等运行依赖；LLM 暂未配置时会明确显示但开发环境仍可启动。
- `GET /status`：必须携带 `X-Ops-Token`，不得暴露给公网。
- `POST /v1/ai/tasks`、`GET /v1/ai/tasks/{task_id}`：必须携带 `X-Internal-Token`。
- `ai-worker` 容器消费 `review`、`report`、`knowledge_ingest` 队列；积压时先检查 Redis、Worker 日志和模型/Embedding 配置。

任何请求使用 `X-Trace-Id`，按该值在日志和后续 Langfuse 中串联一次调用。

## 常见故障

- `401/403`：检查 JWT 的 `sub` 是否为用户 ID 字符串、角色是否为学生、会话是否归属该学生。
- 只有 `status(degraded)`：检查 LLM URL、Key、模型名和网络；生产不要打开 synthetic fallback。
- 没有 citation：检查 Embedding 维度、Milvus collection 和教材入库状态。
- 评分/报告返回 `AI_UNAVAILABLE` 或 `OUTPUT_SCHEMA_INVALID`：这是保护性失败，不能人工改成 0/70/85 分；检查模型配置、上游限流和结构化输出 schema。
- SSE 卡住：确认反向代理关闭缓冲（`X-Accel-Buffering: no`）并检查上游超时。

## 发布验证

在 `ai` 目录执行 `python -m pytest -q`、`python -m compileall -q app tests` 和 `git diff --check`。容器发布后重复 `/health`、鉴权、聊天 SSE 和视觉 URL 安全用例。

教材开发联调时，把 PDF 放入仓库 `data/objects/textbooks/`，调用 `/knowledge/ingest` 时只提交类似 `textbooks/book.pdf` 的 objectKey。不要提交磁盘绝对路径或公网 URL。
