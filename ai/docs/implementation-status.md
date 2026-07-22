# AI 中台重构交接说明

## 当前运行原则

Spring Boot 是用户、权限、病例、会话和正式成绩的唯一事实来源。FastAPI 不直接访问业务 MySQL，只负责 AI 编排、RAG、流式事件和异步任务。LLM、Vision、Embedding 可以在开发环境留空，但任何正式评分、报告或学习路径都不能返回伪造结果。

## 已落地模块

- `app/api/chat.py`：学生鉴权后转交 `ChatWorkflow`，保持现有 SSE 协议。
- `app/workflows/chat_workflow.py`：会话归属、安全规则、RAG、SP、持久化、Mentor 更新。
- `app/adapters/model_gateway.py`：隔离具体 OpenAI 兼容客户端。
- `app/workers/`：Redis 任务契约、幂等入队、领取、重试、失败状态和批阅 Worker。
- `app/adapters/object_storage.py`：受控 objectKey 读取；开发使用本地目录，生产可替换为 S3/MinIO/OSS。
- `app/workers/knowledge_worker.py`：教材解析、Embedding 和 Milvus 写入链路。
- `app/workers/report_worker.py`：从 Spring Boot 获取真实会话事实后生成报告。
- `app/api/tasks.py`：内部任务提交和状态查询。
- `app/workers/runner.py`：独立 Worker 进程入口，Compose 中由 `ai-worker` 服务运行。
- `app/core/errors.py`：稳定机器错误码，不向客户端暴露供应商堆栈。
- `app/api/health.py`：存活、就绪和受保护的运维状态接口。

## LLM 为空时

保留 `LLM_BASE_URL=`、`LLM_API_KEY=`。聊天在开发模式输出明确的 degraded 事件；批阅、评分和报告返回 `AI_UNAVAILABLE` 或 `OUTPUT_SCHEMA_INVALID`。生产必须关闭 `ENABLE_LLM_FALLBACK`，并在接入真实模型前保持相关能力不可用，而不是产生假结果。

## 启动与验证

在仓库根目录准备 `.env`，至少修改 JWT、内部 Token 和运维 Token。进入 `ai` 目录执行：

```powershell
python -m pip install -r requirements.txt
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
python -m pytest -q
```

生产还必须配置明确的 `CORS_ALLOWED_ORIGINS`、`VISION_ALLOWED_HOSTS`，并关闭两个 fallback 开关。

## 尚需外部资源才能启用的能力

- LLM/LangGraph 实际推理：需要模型 URL、Key 和模型名。
- 教材真实检索：需要 Embedding 服务以及可用 Milvus collection。
- Vision：需要多模态模型和受控对象存储来源。
- Langfuse/DeepEval：代码边界和依赖位置已预留，启用需要部署服务及医学专家黄金数据集。
