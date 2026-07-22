# 智愈寻真 FastAPI AI 中台生产化重构设计

日期：2026-07-22  
适用项目：`E:/zhiyu`  
文档状态：已确认的目标架构设计，尚未开始代码迁移  
主要读者：接手 FastAPI、Spring Boot、RAG、Agent 或部署工作的开发者、测试工程师和医学教学负责人

## 1. 先看结论

本次重构不推倒现有系统，也不更换 Flutter、Spring Boot、MySQL、Redis、Milvus 和 Docker 的总体技术路线。

要改变的是 FastAPI 内部的职责边界：当前 API 文件同时负责鉴权、读取业务数据、拼 Prompt、调用模型、解析结果、降级和回写；目标架构把这些职责拆成稳定的 API 层、业务工作流层、领域规则层、Agent 层、RAG 层、模型适配层和基础设施适配层。

目标系统只制作一个真正的 Agent：`SP Agent`。它负责在多轮问诊中扮演标准化病人。Mentor、Evaluator、Reviewer、学习路径、报告和安全检查都不做自由行动的 Agent，而是可测试、可重放、可人工复核的工作流或规则模块。

目标链路如下：

```text
Flutter Mobile
    |
    | 用户 JWT / SSE
    v
Spring Boot 业务中台 <------> MySQL / Redis
    |
    | 内部服务 Token
    v
FastAPI AI 中台
    |
    +-- API 层：鉴权、参数、错误、SSE
    +-- Workflow：问诊、批阅、评分、报告、知识入库
    +-- Domain：安全、评分、引用、状态规则
    +-- SP Agent：唯一允许自主选择下一步的 Agent
    +-- RAG：Embedding、Milvus、重排、引用校验
    +-- Model Gateway：模型选择、超时、重试、成本
    +-- Adapters：Spring、Milvus、对象存储、Redis
    |
    +-- 大模型供应商
    +-- Milvus
    +-- Langfuse / 指标系统
```

## 2. 当前代码与目标代码的关系

当前代码不是废弃重写，而是迁移到目标边界：

| 当前位置 | 目标位置 | 处理方式 |
|---|---|---|
| `ai/app/api/chat.py` | `api/chat.py` + `workflows/chat_workflow.py` | API 保留薄入口，业务流程移到 Workflow |
| `ai/app/api/review.py` | `api/review.py` + `workflows/review_workflow.py` | API 不再直接拼 Prompt |
| `ai/app/api/daily_case.py` | `api/daily_case.py` + `workflows/daily_case_workflow.py` | 标准答案优先，LLM 只补解释 |
| `ai/app/api/learning_path.py` | `api/learning_path.py` + `workflows/learning_path_workflow.py` | 先读取真实学情，再生成建议 |
| `ai/app/api/report.py` | `api/report.py` + `workflows/report_workflow.py` | 只使用已保存的会话、评分和错题 |
| `ai/app/api/embed.py` | `api/knowledge.py` + `workflows/knowledge_ingest_workflow.py` | 变成可追踪的知识入库任务 |
| `ai/app/api/vision.py` | `api/vision.py` + `workflows/vision_workflow.py` | 加鉴权、图片来源校验和输出校验 |
| `ai/app/services/llm_client.py` | `services/model_gateway.py` | 统一模型调用、成本、重试和结构化输出 |
| `ai/app/services/rag_service.py` | `services/retrieval_service.py` | 检索不负责生成，只返回带版本的证据 |
| `ai/app/services/milvus_service.py` | `adapters/milvus_repository.py` | 只负责向量存取，不决定业务策略 |
| `ai/app/services/backend_client.py` | `adapters/spring_client.py` | 只负责内部 API 调用和响应契约校验 |
| `ai/app/services/pdf_service.py` | `services/document_parser.py` | 解析、切块和文档元数据独立管理 |
| `ai/app/agents/sp_agent.py` | `agents/sp_agent.py` | 保留并改成有状态、受工具白名单约束的 Agent |
| `ai/app/agents/mentor_agent.py` | `workflows/mentor_workflow.py` | LLM 信息抽取 + 确定性标准路径比较 |
| `ai/app/agents/evaluator_agent.py` | `workflows/evaluation_workflow.py` | 量表规则优先，LLM 负责解释 |
| `ai/app/agents/reviewer_agent.py` | `workflows/review_workflow.py` | 结构化批阅流水线，不允许假分数降级 |
| `ai/app/prompts/templates.py` | `prompts/registry.py` + `prompts/*.py` | Prompt 版本化、可追踪、禁止散落拼接 |
| `ai/app/core/security.py` | `core/security.py` + `domain/policies/` | 认证与资源权限分开 |
| `ai/app/core/config.py` | `core/config.py` | 修复环境变量映射，生产配置拒绝默认密钥 |
| `ai/app/core/logging.py` | `observability/logging.py` | 使用 `contextvars`，不使用进程级共享请求上下文 |

迁移完成后，旧模块可以保留兼容导出，但不再在新代码中直接调用旧实现。

## 3. 设计原则和明确不做的事

### 3.1 必须遵守的原则

1. Spring Boot 是用户、权限、病例、作业、会话和正式成绩的唯一业务事实来源。
2. FastAPI 不直接访问业务 MySQL；通过内部接口获取快照并回写 AI 结果。
3. 外部输入、教师病例、教材文本、模型输出都按不可信数据处理。
4. 所有模型输出先通过 Pydantic Schema 和领域规则，再进入业务系统。
5. AI 不可用时，聊天可以说明性降级；评分、批阅和医学判读必须返回不可用或进入人工复核，不能返回伪造分数。
6. 每个模型结果必须能追踪到用户、会话、病例快照、Prompt 版本、模型版本和知识库版本。
7. API、工作流、规则、模型和外部适配器之间通过明确接口通信，不共享任意字典。
8. 能用规则确定的事不交给模型，例如权限、会话归属、作业状态、标准答案判定和分数计算。

### 3.2 明确不引入的复杂度

- 不引入第二套用户、权限或角色系统。
- 不把每个 LLM 调用都包装成 Agent。
- 不同时引入 LangGraph、PydanticAI、LlamaIndex、Haystack 和 RAGFlow。
- 不让 Agent 拥有任意网络请求、任意 SQL、任意文件读取工具。
- 不在本次终态设计中加入独立通用 API Gateway、服务注册中心、微服务治理平台或通用低代码系统。
- 不在 FastAPI 内复制一份 Spring Boot 的病例、用户和作业数据库。
- 不用模型自动生成正式课程成绩；正式成绩必须有规则和教师复核。

### 3.3 开源技术选型定案

本设计对核心开源组件做明确选择，避免接手人再次在多个同类框架之间摇摆：

| 项目 | 是否采用 | 用途 | 许可证 | 使用边界 |
|---|---:|---|---|---|
| [LangGraph](https://github.com/langchain-ai/langgraph) | 是 | SP Agent 状态图、节点路由和可恢复状态 | MIT | 只用于 SP 多轮问诊，不接管全部业务 Workflow |
| [LiteLLM](https://github.com/BerriAI/litellm) | 是 | 自托管模型网关、供应商切换、预算和调用记录 | 核心 MIT，企业目录单独授权 | FastAPI 只依赖内部 `ModelGateway`，不把 LiteLLM 类型扩散到业务代码 |
| [Haystack](https://github.com/deepset-ai/haystack) | 是 | 教材解析后的检索 Pipeline、元数据过滤和重排编排 | Apache-2.0 | 继续使用当前 Milvus，不启用 Haystack Agent |
| [Langfuse](https://github.com/langfuse/langfuse) | 是 | 自托管 Trace、Prompt 版本、Token、费用和评测数据集 | 社区代码 MIT，企业目录单独授权 | 医疗文本先脱敏，禁止直接使用第三方 SaaS 保存完整病历 |
| [DeepEval](https://github.com/confident-ai/deepeval) | 是 | 自动化 LLM、Agent 和 RAG 质量测试 | Apache-2.0 | 作为 `tests/evals/` 的执行框架，医学专家黄金集仍由项目维护 |
| RAGFlow | 否 | 完整 RAG 平台 | Apache-2.0 | 会重复现有 FastAPI、Milvus 和业务治理能力，部署过重 |
| PydanticAI | 否 | Agent 框架 | MIT | 和 LangGraph 职责重叠；本项目继续直接使用 Pydantic Schema |
| LlamaIndex | 否 | RAG/Agent 框架 | MIT | 与 Haystack 职责重叠，不同时引入 |
| NeMo Guardrails | 暂不采用 | 通用对话护栏 | Apache-2.0 | 中文医学教学规则需要本项目自己的 `SafetyPolicy`，避免双重规则系统 |

组件采用方式是“通过项目内部接口隔离”，而不是让业务代码直接依赖第三方框架。未来即使更换 LangGraph、LiteLLM 或 Haystack，`Workflow` 和 `Domain` 层也不应跟着重写。

## 4. 目标目录结构

下面是重构完成后的完整 FastAPI 目录。`__init__.py` 文件只做包标记或导出，不放业务逻辑。

```text
ai/
├── Dockerfile
├── requirements.txt
├── pyproject.toml
├── app/
│   ├── __init__.py
│   ├── main.py
│   │
│   ├── api/
│   │   ├── __init__.py
│   │   ├── chat.py
│   │   ├── vision.py
│   │   ├── review.py
│   │   ├── daily_case.py
│   │   ├── learning_path.py
│   │   ├── report.py
│   │   ├── knowledge.py
│   │   └── health.py
│   │
│   ├── core/
│   │   ├── __init__.py
│   │   ├── config.py
│   │   ├── errors.py
│   │   ├── security.py
│   │   ├── dependencies.py
│   │   └── lifecycle.py
│   │
│   ├── domain/
│   │   ├── __init__.py
│   │   ├── enums.py
│   │   ├── errors.py
│   │   ├── policies/
│   │   │   ├── safety_policy.py
│   │   │   ├── session_policy.py
│   │   │   ├── citation_policy.py
│   │   │   └── output_policy.py
│   │   ├── scoring/
│   │   │   ├── osce_rubric.py
│   │   │   ├── record_rubric.py
│   │   │   └── score_calculator.py
│   │   └── schemas/
│   │       ├── common.py
│   │       ├── chat.py
│   │       ├── review.py
│   │       ├── knowledge.py
│   │       └── events.py
│   │
│   ├── workflows/
│   │   ├── __init__.py
│   │   ├── chat_workflow.py
│   │   ├── mentor_workflow.py
│   │   ├── evaluation_workflow.py
│   │   ├── review_workflow.py
│   │   ├── daily_case_workflow.py
│   │   ├── learning_path_workflow.py
│   │   ├── report_workflow.py
│   │   ├── vision_workflow.py
│   │   └── knowledge_ingest_workflow.py
│   │
│   ├── agents/
│   │   ├── __init__.py
│   │   ├── sp_agent.py
│   │   ├── sp_state.py
│   │   ├── sp_tools.py
│   │   └── sp_prompts.py
│   │
│   ├── services/
│   │   ├── __init__.py
│   │   ├── model_gateway.py
│   │   ├── structured_output.py
│   │   ├── retrieval_service.py
│   │   ├── rerank_service.py
│   │   ├── document_parser.py
│   │   ├── chunker.py
│   │   ├── prompt_registry.py
│   │   ├── token_budget.py
│   │   └── idempotency_service.py
│   │
│   ├── adapters/
│   │   ├── __init__.py
│   │   ├── spring_client.py
│   │   ├── milvus_repository.py
│   │   ├── embedding_client.py
│   │   ├── object_storage.py
│   │   ├── redis_client.py
│   │   └── langfuse_client.py
│   │
│   ├── prompts/
│   │   ├── __init__.py
│   │   ├── versions.py
│   │   ├── sp_system_v1.py
│   │   ├── mentor_extract_v1.py
│   │   ├── reviewer_extract_v1.py
│   │   ├── evaluator_extract_v1.py
│   │   └── safety_classify_v1.py
│   │
│   ├── workers/
│   │   ├── __init__.py
│   │   ├── task_models.py
│   │   ├── task_queue.py
│   │   ├── review_worker.py
│   │   ├── report_worker.py
│   │   └── knowledge_worker.py
│   │
│   └── observability/
│       ├── __init__.py
│       ├── logging.py
│       ├── tracing.py
│       ├── metrics.py
│       └── model_events.py
│
├── tests/
│   ├── unit/
│   ├── integration/
│   ├── contract/
│   ├── security/
│   └── evals/
│       ├── datasets/
│       ├── test_sp_agent.py
│       ├── test_rag_grounding.py
│       ├── test_review_quality.py
│       └── test_safety_boundaries.py
└── docs/
    ├── agent-contracts.md
    ├── prompt-versioning.md
    └── runbook.md
```

## 5. 每个目录和文件应该放什么

### 5.1 应用入口和 API 层

#### `app/main.py`

只负责创建 FastAPI 应用、注册中间件、注册路由和异常处理器。

必须包含：

- `lifespan`：初始化日志、HTTP 客户端、Redis、Milvus、模型网关和 Langfuse。
- CORS 白名单配置，不允许生产环境 `allow_origins=["*"]`。
- `RequestContextMiddleware`：生成或透传 `trace_id`。
- 统一 `ApiError`、Pydantic 校验错误和未知异常响应。
- 路由前缀和版本信息。

禁止包含：模型调用、Prompt、数据库查询和业务分支。

#### `app/api/chat.py`

职责只有四件事：

1. 解析 `ChatRequest`。
2. 依赖注入学生身份。
3. 调用 `ChatWorkflow.stream`。
4. 把工作流事件转换为 SSE。

它不能读取 Milvus、拼接病例上下文或直接调用 `llm_client`。

#### `app/api/review.py`

校验 `X-Internal-Token` 和请求字段，调用 `ReviewWorkflow`。同步接口只返回任务状态；耗时批阅使用任务 ID 查询结果，不让 HTTP 请求无限等待。

#### `app/api/knowledge.py`

替代旧 `embed.py`。只接受 Spring Boot 发来的已授权教材对象键，不接受任意外部 URL。返回 `ingestion_id`、状态和错误码。

#### `app/api/vision.py`

校验学生 JWT、会话归属和对象存储图片键。图片不能由客户端提供任意公网 URL。调用 `VisionWorkflow`，输出必须经过内容和安全校验。

#### `app/api/health.py`

提供三个不同目的的接口：

- `/health/live`：进程存活，不访问外部依赖。
- `/health/ready`：检查必需依赖是否可用。
- `/status`：仅运维认证后返回依赖状态，不公开模型配置、内部地址或向量数量。

### 5.2 配置、鉴权和生命周期

#### `app/core/config.py`

使用 `pydantic-settings`，为每个配置显式声明环境变量别名，避免字段名和 Compose 名称不一致。

核心配置：

```python
class Settings(BaseSettings):
    env: Literal["dev", "test", "prod"]
    jwt_secret: SecretStr
    internal_token: SecretStr = Field(validation_alias="AI_INTERNAL_TOKEN")
    llm_base_url: str | None = None
    llm_api_key: SecretStr | None = None
    llm_model: str
    embedding_base_url: str | None = None
    embedding_api_key: SecretStr | None = None
    milvus_host: str
    milvus_port: int
    enable_llm_fallback: bool = False
    enable_milvus_fallback: bool = False
    cors_allowed_origins: list[str] = []
```

生产启动校验：

- `env=prod` 时拒绝 `dev-only-secret-key`、`dev-internal-token` 和空 JWT 密钥。
- `env=prod` 时默认关闭模型和 Milvus 的伪造 fallback。
- 只允许显式配置的 CORS Origin。
- `ENV_MODE` 和 `AI_INTERNAL_TOKEN` 必须通过测试确认已映射到 Settings。

#### `app/core/security.py`

包含独立的依赖：

- `require_student_jwt`：验证签名、算法、`type=access`、`sub`、`role=student`、过期时间。
- `require_internal_token`：使用常量时间比较校验服务 Token。
- `require_operator`：保护运维状态和任务管理接口。

资源归属不能只靠 JWT 角色判断，必须由 `SessionPolicy` 调 Spring Boot 做对象级校验。

#### `app/core/errors.py`

定义机器可读错误码：

```text
AUTH_REQUIRED
FORBIDDEN
SESSION_NOT_FOUND
SESSION_NOT_OWNED
AI_UNAVAILABLE
AI_DEGRADED
KNOWLEDGE_EVIDENCE_INSUFFICIENT
OUTPUT_SCHEMA_INVALID
SAFETY_BLOCKED
TASK_NOT_FOUND
TASK_ALREADY_COMPLETED
DEPENDENCY_UNAVAILABLE
```

客户端永远收到稳定的 `code` 和用户可读的 `message`，不收到供应商异常、URL、堆栈或内部配置。

#### `app/core/lifecycle.py`

集中管理异步资源：

- 一个共享 `httpx.AsyncClient`。
- 一个模型网关实例。
- 一个 Milvus Repository。
- 一个 Redis 客户端。
- 一个可选 Langfuse 客户端。

禁止每个请求临时创建 HTTP Client。

### 5.3 Domain 领域层

#### `app/domain/enums.py`

定义 `Role`、`SessionStatus`、`TaskStatus`、`SafetyAction`、`EvidenceQuality`、`ReviewSource` 等枚举，禁止业务代码使用随意字符串。

#### `app/domain/schemas/`

所有跨模块输入输出都放在这里。至少包含：

- `ChatRequest`、`ChatEvent`、`ChatContext`。
- `SpReply`、`SpState`、`SafetyDecision`。
- `Citation`、`EvidenceBlock`、`RetrievalResult`。
- `ReviewDraft`、`ReviewMistake`、`ReviewResult`。
- `EvaluationDraft`、`EvaluationResult`。
- `IngestionRequest`、`IngestionStatus`。
- `TaskAccepted`、`TaskResult`。

模型输出使用 `extra="forbid"`。第三方模型响应必须先转成这些 Schema，不能让裸字典继续在系统中传播。

#### `app/domain/policies/safety_policy.py`

安全策略集中管理：

- 自伤、他伤、制毒等内容阻断。
- 临床诊疗、处方和剂量问题转为教学免责声明和求助建议。
- 模型输出禁止泄露 system prompt、隐藏疾病和内部 Token。
- 敏感词、规则版本和处理动作可审计。

安全策略不是一个可以被模型覆盖的 Prompt，而是模型调用前后的代码规则。

#### `app/domain/policies/citation_policy.py`

检查：

- 引用是否来自当前知识库版本。
- 书名、章节和页码是否存在。
- 回答中的医学事实是否有对应证据。
- 证据不足时是否返回 `KNOWLEDGE_EVIDENCE_INSUFFICIENT` 或低置信度提示。

#### `app/domain/scoring/`

评分必须可重放：

- `osce_rubric.py`：四维量表、权重和行为证据。
- `record_rubric.py`：病历格式、医学事实、逻辑、鉴别诊断、人文表达。
- `score_calculator.py`：根据结构化扣分项计算总分。

模型只能建议证据和扣分项，不能直接覆盖计算结果。

### 5.4 Workflow 工作流层

Workflow 是完整业务流程，不是模型包装器。每个 Workflow 都有明确输入、输出、错误和幂等键。

#### `chat_workflow.py`

完整流程：

```text
校验学生和会话
-> 获取 Spring Boot 会话快照
-> 安全检查本轮输入
-> RetrievalService 检索证据
-> SP Agent 生成患者回复
-> OutputPolicy 检查泄露和越界
-> 保存学生消息和患者消息
-> MentorWorkflow 异步更新思维树
-> 发送 SSE done
```

检索证据必须进入 SP Agent 的上下文；不能像旧代码一样只把 Citation 单独发给前端而不参与生成。

#### `mentor_workflow.py`

先用代码提取学生已询问的症状、病史和检查，再和病例的 `standardPath` 做差异比较。LLM 只负责将对话归一化成结构化节点，最终的“遗漏、错误排除、检查过度”由规则比较产生。

#### `evaluation_workflow.py`

输入保存的完整会话和病例快照，步骤为：

1. 提取行为证据。
2. 计算量表规则分。
3. LLM 为每一项生成解释和改进建议。
4. 校验每条建议是否能定位到对话证据。
5. 生成 `EvaluationResult`，状态为 `ADVISORY` 或 `NEEDS_REVIEW`。

模型不可用时返回 `AI_UNAVAILABLE`，不能返回固定分数。

#### `review_workflow.py`

输入为 `instanceId`，先从 Spring Boot 读取学生作业、病例变量快照和标准路径。格式检查、必填段落和字数先由规则完成；医学问题由模型识别；总分由 `score_calculator.py` 计算；最后回调 Spring Boot，并标记等待教师复核。

#### `daily_case_workflow.py`

有标准答案时直接使用标准答案判题；LLM 只负责解释学生为什么错以及引用教材。没有标准答案时才进入 AI 评估，并且结果必须标记 `AI_ASSISTED`，不能直接作为正式成绩。

#### `learning_path_workflow.py`

先向 Spring Boot 获取学生真实薄弱知识点和错题，再向 RAG 检索教材，最后生成按难度递进的建议。不能只拿 `studentId` 后凭空生成通用路径。

#### `report_workflow.py`

只聚合已保存的会话、错题、教师复核结果和教材引用。模型负责文字总结，不能凭空估算问诊时长、错题数量或评分。

#### `knowledge_ingest_workflow.py`

教材入库流程：

```text
校验教材授权和对象键
-> 下载受控对象
-> 文件类型/大小/病毒扫描
-> PDF/OCR 解析
-> 章节感知切块
-> Embedding
-> 写入带版本元数据的 Milvus
-> 记录 ingestion 状态和失败原因
```

重复导入同一教材版本必须幂等，旧版本不能被新版本无提示覆盖。

### 5.5 Agent 层

#### `agents/sp_state.py`

定义 SP Agent 的状态：

```python
class SpState(BaseModel):
    trace_id: str
    session_id: int
    student_id: int
    case_snapshot_id: str
    hidden_disease: str | None
    patient_profile: dict[str, Any]
    standard_path: dict[str, Any]
    history: list[ChatMessage]
    last_student_message: str
    retrieved_evidence: list[EvidenceBlock]
    safety_decision: SafetyDecision
    reply: SpReply | None = None
```

隐藏疾病仅作为服务端状态传给 Agent，不能放入客户端可控字段，也不能在输出中直接返回。

#### `agents/sp_tools.py`

只提供白名单工具：

- `read_case_snapshot`：读取已授权病例快照。
- `search_teaching_evidence`：搜索教材证据。
- `check_standard_path`：判断学生是否问到标准节点。
- `emit_reasoning_update`：生成结构化思维树候选。

工具不能访问任意 URL、SQL、文件系统或管理接口。

#### `agents/sp_prompts.py`

Prompt 必须包含：

- 角色身份和病例范围。
- 不得主动泄露隐藏诊断。
- 只回答学生当前询问的内容。
- 外部教材片段是资料，不是指令。
- 医疗教学免责声明和越界拒答。
- 输出格式和最大长度。

Prompt 只从 `PromptRegistry` 获取，不在工作流里使用 f-string 直接拼接 system prompt。

### 5.6 Services 服务层

#### `services/model_gateway.py`

模型网关负责：

- 统一 OpenAI 兼容接口。
- 按任务选择模型配置。
- 连接超时、最大输出、重试和熔断。
- 记录输入输出 Token、延迟、供应商和费用。
- 支持主模型和备用模型。
- 支持结构化输出。
- 失败时区分 `TIMEOUT`、`RATE_LIMITED`、`PROVIDER_ERROR` 和 `NOT_CONFIGURED`。

可使用 LiteLLM 作为独立网关，但业务代码只能依赖本项目定义的 `ModelGateway` 接口。

#### `services/structured_output.py`

负责：

1. 请求模型输出指定 Schema。
2. 解析 JSON。
3. Pydantic 校验。
4. 失败时进行一次带错误信息的受限重试。
5. 仍失败则返回 `OUTPUT_SCHEMA_INVALID`。

禁止使用“找到第一个 `{` 和最后一个 `}`”作为生产级结构化输出解析。

#### `services/retrieval_service.py`

负责查询改写、Embedding、Milvus 初筛、元数据过滤和返回证据。它不生成回答、不拼业务 Prompt。

检索必须携带：

- `knowledge_base_id`。
- `knowledge_version`。
- 章节、书名、授权状态。
- 相似度分数。
- 文本片段 ID。

#### `services/rerank_service.py`

对初筛结果重排，过滤低于阈值的证据。没有可靠证据时返回空列表，而不是用零向量伪造命中。

#### `services/document_parser.py` 和 `services/chunker.py`

解析教材文本、章节、页码、表格和 OCR 结果。切块按章节和语义边界完成，保存原始文档哈希和 chunk 哈希，支持重复导入检测。

#### `services/prompt_registry.py`

根据 `(agent_name, prompt_version)` 返回 Prompt，并把版本写入 Trace。Prompt 改动必须更新版本号，不能静默修改 `v1`。

#### `services/token_budget.py`

按用户、班级、功能和日累计限制 Token；达到限制时返回可理解的 `AI_BUDGET_EXCEEDED`。

#### `services/idempotency_service.py`

以 `session_id + client_message_id` 或 `task_type + business_id + version` 作为幂等键，避免 SSE 重连、重复提交和回调重试造成重复消息或重复批阅。

### 5.7 Adapters 外部适配器

#### `adapters/spring_client.py`

只允许调用已登记的 Spring Boot 内部接口。每个响应使用 Pydantic Schema 校验。失败时抛出统一 `BackendDependencyError`，不吞掉异常并假装成功。

#### `adapters/milvus_repository.py`

只提供 `upsert`、`search`、`delete_by_version`、`count_by_version`。Milvus SDK 的同步调用必须放入线程池或替换为异步客户端，不能阻塞 FastAPI 事件循环。

#### `adapters/object_storage.py`

使用受控对象键和短期签名 URL。拒绝 `file://`、localhost、私网 IP、云元数据地址和未经 allowlist 的域名。

#### `adapters/langfuse_client.py`

记录 Prompt、模型、用户匿名 ID、会话 ID、输入输出 Token、延迟、费用、错误和评测标签。医疗文本按脱敏策略处理，不能把完整病历无保护写入第三方服务。

### 5.8 Prompt 文件

每个 Prompt 文件只返回模板，不执行网络或业务逻辑。

命名格式：`<purpose>_v<major>.py`。版本变更规则：

- 只修错别字且不改变行为：小版本记录在 `versions.py`。
- 改变输出格式、评分逻辑或安全规则：升级主版本。
- 任何线上结果都能通过版本号定位回原始 Prompt。

### 5.9 Workers 异步任务

批阅、教材入库和报告生成不应全部占用请求线程。`workers/` 负责任务模型、队列、重试、状态和死信记录。

任务状态：

```text
PENDING -> RUNNING -> SUCCEEDED
                   -> FAILED_RETRYABLE
                   -> FAILED_FINAL
                   -> CANCELLED
```

本设计使用现有 Redis 承担轻量任务状态和队列，不新增 Kafka、RabbitMQ 等独立消息平台。任务必须有幂等键、可见状态、最大重试次数和最终失败记录。

### 5.10 其余文件逐项说明

下表补齐目标目录中没有单独展开的文件，避免出现“创建了文件但不知道写什么”的情况：

| 文件 | 具体内容 |
|---|---|
| `ai/pyproject.toml` | Ruff、mypy、pytest、coverage 和项目 Python 版本配置；不重复声明 Docker 运行依赖 |
| `app/api/__init__.py` | 导出各 APIRouter，供 `main.py` 统一注册 |
| `app/core/dependencies.py` | FastAPI 依赖注入函数，例如获取 `Settings`、`SpringClient`、`ModelGateway`、`RetrievalService` 和 Workflow |
| `app/core/lifecycle.py` | 创建和关闭共享客户端，向 `app.state` 注册资源，不包含业务 Workflow |
| `app/domain/errors.py` | 领域异常类，例如证据不足、评分不可用、状态冲突；由 API 层映射 HTTP 状态 |
| `app/domain/schemas/common.py` | `TraceContext`、分页、统一 ID、基础结果和时间字段 |
| `app/domain/schemas/chat.py` | 聊天请求、消息、病例上下文、SP 输出和思维树模型 |
| `app/domain/schemas/review.py` | 批阅输入、错误项、量表证据、AI 草稿、规则分数和教师复核状态 |
| `app/domain/schemas/knowledge.py` | 教材、版本、Chunk、EvidenceBlock、检索结果和入库任务模型 |
| `app/domain/schemas/events.py` | SSE 事件的判别联合类型，确保不同事件字段不会混用 |
| `app/prompts/versions.py` | 当前启用 Prompt 版本映射和变更说明，不保存密钥或运行配置 |
| `app/workers/task_models.py` | `TaskType`、`TaskStatus`、任务输入、重试次数、错误和结果引用 |
| `app/workers/task_queue.py` | Redis 入队、领取、续租、确认、重试和死信操作；不包含具体批阅逻辑 |
| `app/workers/review_worker.py` | 领取批阅任务，调用 `ReviewWorkflow`，更新状态并执行幂等回调 |
| `app/workers/report_worker.py` | 领取报告任务，调用 `ReportWorkflow`，保存产物引用 |
| `app/workers/knowledge_worker.py` | 领取教材任务，调用 `KnowledgeIngestWorkflow`，记录各步骤状态 |
| `app/observability/logging.py` | JSON 日志格式、`contextvars` 上下文、敏感字段过滤 |
| `app/observability/tracing.py` | OpenTelemetry/Langfuse span 创建、父子链路和异常标记 |
| `app/observability/metrics.py` | Prometheus Counter、Histogram 和 Gauge 定义，不在业务代码里动态创建指标 |
| `app/observability/model_events.py` | 统一记录模型成功、失败、降级、Token 和费用事件，并可回调 Spring Boot |
| `tests/unit/` | 不访问网络的规则、Schema、PromptRegistry 和分数计算测试 |
| `tests/integration/` | FastAPI 路由、Workflow、Redis、Milvus 适配器和 SSE 集成测试 |
| `tests/contract/` | FastAPI 与 Spring Boot 内部接口的请求/响应契约测试 |
| `tests/security/` | 越权、默认密钥、SSRF、Prompt Injection、日志泄漏和限流测试 |
| `tests/evals/datasets/` | 医学专家标注的 JSONL 黄金集和数据版本说明 |
| `ai/docs/agent-contracts.md` | SP Agent 状态、节点、工具、输入输出和禁止行为 |
| `ai/docs/prompt-versioning.md` | Prompt 命名、审核、升级、回滚和评测规则 |
| `ai/docs/runbook.md` | 启停、健康检查、密钥轮换、模型切换、队列积压、Milvus 故障和回滚步骤 |

### 5.11 Spring Boot、Docker 和 Nginx 的配套修改

FastAPI 内部重构不能靠悄悄改变 JSON 完成。下面这些现有文件需要做最小配套修改：

| 文件 | 修改内容 |
|---|---|
| `backend/src/main/java/com/zhiyu/client/AiPlatformClient.java` | 不再返回未经校验的 `String`；为批阅、任务、报告、知识入库定义类型化请求/响应；统一发送 `traceId` 和幂等键；识别 4xx/5xx 和 AI 错误码 |
| `backend/src/main/java/com/zhiyu/vo/AiSessionContextVO.java` | 增加 `caseSnapshotId`、病例版本、标准路径版本和允许使用的知识库范围 |
| `backend/src/main/java/com/zhiyu/controller/internal/InternalCallbackController.java` | 接收幂等键和 `traceId`，重复回调返回原结果，不重复写数据库 |
| `backend/src/main/java/com/zhiyu/service/impl/InternalCallbackServiceImpl.java` | 校验批阅对应的作业实例、当前状态和结果来源；禁止 AI 回调直接覆盖教师结果 |
| `backend/src/main/java/com/zhiyu/service/impl/AiSessionContextServiceImpl.java` | 返回不可变病例快照和已保存历史；限制单次历史长度，避免上下文无限增长 |
| `backend/src/main/java/com/zhiyu/service/dto/internal/*` | 增加结构化 AI 状态、Prompt/模型/知识版本、幂等键和失败原因字段 |
| `backend/src/main/resources/application.yml` | 保持 `AI_INTERNAL_TOKEN`、AI Base URL、超时和重试配置与 FastAPI 一致 |
| `.env.example` | 删除可误用于生产的默认密钥，补 CORS、Langfuse、LiteLLM、预算和对象存储变量说明 |
| `docker-compose.yml` | 修复 `ENV_MODE`、`AI_INTERNAL_TOKEN` 映射；增加 LiteLLM、Langfuse 或对应外部地址；Worker 使用同一 AI 镜像但不同启动命令 |
| `docker-compose.prod.yml` | 生产禁用 reload，不公开 FastAPI 内部管理端口，配置 Worker 资源限制和健康检查 |
| `deploy/nginx/nginx.conf` | 只公开允许的 `/api/v1/ai/*`；不公开 `/review`、`/embed`、`/status` 等内部路由；保留 SSE 关闭缓冲 |

业务数据库是否新增 AI 任务审计表，由 Spring Boot 数据模型设计决定；即使 Redis 保存运行任务状态，最终批阅结果、教师复核、失败原因和审计记录仍必须落到业务数据库，不能只存在 Redis。

### 5.12 对现有接口的兼容规则

重构期间不随意修改 Flutter 和 Spring Boot 已经依赖的公开行为：

- `/v1/ai/chat/stream` 路径、`message`/`citation`/`tree`/`socrates`/`error`/`done` 事件名继续保留。
- 现有内部接口路径先保留，响应增加字段时使用可选字段，不能删除旧字段或改变已有字段类型。
- 旧 `R {code,message,data}` 成功响应在已有 Spring Boot 调用链中继续兼容；新错误同时使用正确 HTTP 状态和结构化错误体。
- 需要彻底改变契约的接口创建明确的新版本，不通过条件分支让同一路径返回两种完全不同的结构。
- 所有契约变更先补 `tests/contract/`，再修改调用方。

## 6. Agent 具体设计

### 6.1 只有 SP Agent 是 Agent

SP Agent 的职责是“根据病例快照和学生问题，扮演标准化病人”。它不负责评分、不决定教师权限、不访问任意网络、不修改业务数据。

它的输入：

- 病例快照 ID。
- 患者画像。
- 隐藏疾病和标准路径。
- 已保存的对话历史。
- 学生本轮问题。
- 经过筛选的教学证据。

它的输出：

```python
class SpReply(BaseModel):
    text: str = Field(min_length=1, max_length=500)
    emotion: Literal["calm", "anxious", "painful", "confused"]
    disclosed_facts: list[str]
    should_update_tree: bool
    safety_notice: str | None = None
```

SP Agent 的长期业务历史仍保存在 Spring Boot/MySQL。LangGraph checkpoint 只保存执行中的短期节点状态，使用 Redis 并设置 TTL；它不是新的业务事实来源。服务重启后应从 Spring Boot 的会话历史重建状态，而不是依赖某个 FastAPI worker 的内存。

### 6.2 SP Agent 节点

```text
START
  -> load_state
  -> safety_check
  -> retrieve_evidence
  -> generate_patient_reply
  -> validate_reply
  -> persist_reply
  -> END
```

`validate_reply` 至少检查：

- 是否泄露隐藏疾病或标准答案。
- 是否出现处方、剂量或真实临床诊疗承诺。
- 是否回答了学生没有问的问题。
- 是否超过长度限制。
- 是否符合患者画像和情绪。
- 是否包含无来源的医学事实。

如果校验失败，不自动把失败内容发给学生；返回安全拒答或重新生成一次。再次失败则结束本轮并记录 `OUTPUT_REJECTED`。

### 6.3 Mentor、Evaluator、Reviewer 怎么做

它们是工作流中的 LLM 节点：

| 名称 | LLM 做什么 | 代码规则做什么 |
|---|---|---|
| Mentor | 将对话抽取成症状/病史/检查节点 | 和标准路径比较遗漏、误排除、过度检查 |
| Evaluator | 根据证据生成评语和改进建议 | 根据 OSCE 量表计算分数 |
| Reviewer | 标记病历中的疑似问题并解释 | 校验位置、扣分范围、总分和教师复核状态 |
| Safety | 可选分类模型 | 最终阻断、脱敏和拒答策略 |

任何节点都不能绕过领域规则直接写正式成绩。

## 7. RAG 知识库设计

### 7.1 知识元数据

每个 Milvus chunk 除向量和文本外，必须包含：

```text
chunk_id
textbook_id
textbook_version
knowledge_base_id
authorization_status
book_name
edition
chapter
page_number
source_hash
chunk_hash
status
created_at
```

不能只用 `tb{textbookId}_c{idx}` 作为永久 ID，因为教材更新、删除和重新切块后会产生脏数据。

### 7.2 检索和生成顺序

```text
学生问题
  -> 查询改写
  -> Embedding
  -> Milvus 初筛
  -> 元数据过滤
  -> reranker 重排
  -> 相似度阈值
  -> EvidenceBlock
  -> 放入模型上下文
  -> 生成回答
  -> CitationPolicy 校验
```

Embedding 服务不可用时不能返回零向量并继续当作正常检索。应该返回 `RETRIEVAL_UNAVAILABLE`，由工作流决定是否只提供明确的无依据提示。

### 7.3 知识入库安全

- `fileUrl` 改为 `objectKey`。
- 只能读取服务端配置的对象存储。
- 校验 PDF 文件头、大小、页数和 MIME。
- 扫描宏、脚本和恶意内容。
- 扫描 PDF 文本中的 Prompt Injection，把它作为资料文本，永不当作系统指令。
- 只有审核通过的教材版本才能被线上问答检索。

## 8. 模型调用和降级规则

### 8.1 模型配置按任务拆分

不同任务使用不同配置，不使用一个全局温度和 Token 上限：

```text
sp_chat: 低温度、短输出、支持流式
structured_extract: 低温度、严格 JSON
review: 中低温度、较长输出、不可自动正式入分
vision: 独立模型和图片大小限制
embedding: 固定模型和维度
```

### 8.2 降级矩阵

| 能力 | 模型不可用时 | 是否可以作为正式结果 |
|---|---|---|
| SP 问诊 | 返回明确降级提示或安全结束 | 否 |
| 影像分析 | 返回未配置/不可用 | 否 |
| 每日一例有标准答案 | 规则判题，模型只缺少解释 | 是，判题来自标准答案 |
| 每日一例无标准答案 | 进入待人工处理 | 否 |
| 大病历批阅 | 任务失败，可重试 | 否 |
| OSCE 评分 | 任务失败，可人工评分 | 否 |
| 报告 | 使用已有结构化事实，缺少 AI 总结时返回未生成 | 否 |
| RAG | 返回证据不可用 | 否 |

禁止返回固定 70 分、默认四维成绩或“已完成”状态。

## 9. API 契约

### 9.1 错误格式

所有 HTTP 错误统一为：

```json
{
  "error": {
    "code": "AI_UNAVAILABLE",
    "message": "当前 AI 服务暂不可用，请稍后重试。",
    "traceId": "uuid"
  }
}
```

状态码约定：

```text
400 请求格式错误
401 未登录或 Token 无效
403 已登录但没有资源权限
404 资源不存在
409 幂等冲突或状态冲突
422 参数语义校验失败
429 频率或预算超限
502 上游模型/业务中台错误
503 AI 依赖暂不可用
```

### 9.2 SSE 事件契约

所有事件都包含 `trace_id` 和 `session_id`：

```text
event: message
data: {"trace_id":"...","session_id":1,"delta":"您好"}

event: citation
data: {"trace_id":"...","citations":[...]}

event: error
data: {"trace_id":"...","code":"AI_UNAVAILABLE","retryable":true}

event: done
data: {"trace_id":"...","session_id":1,"status":"COMPLETED"}
```

客户端断线时，服务端停止生成或记录取消状态；客户端重连必须带 `client_message_id`，服务端按幂等键判断是否已经保存。

## 10. 安全设计

必须完成以下安全边界：

1. 修复 `AI_INTERNAL_TOKEN` 和 `internal_token` 的环境变量映射，并写启动测试。
2. 生产环境拒绝默认 JWT 和内部 Token。
3. Vision 接口要求学生 JWT，并检查会话归属。
4. PDF/图片只允许受控对象存储键，不允许任意 URL。
5. 阻断 localhost、私网 IP、云元数据 IP、`file://` 和不在 allowlist 的域名。
6. CORS 生产使用明确 Origin 列表。
7. 状态和信息接口不公开密钥配置、内部地址、模型 Key、完整错误和向量数量。
8. 所有模型输入标注数据边界，外部教材和学生文本不能覆盖 system 指令。
9. 输出检查 Prompt 泄露、隐藏疾病泄露、医学诊疗承诺和敏感信息。
10. 日志不记录完整病历、图片地址中的敏感签名、密码、JWT 和验证码。
11. 内部回调使用超时、重试、幂等键和审计日志。
12. 限制每个用户、会话、IP 和功能的并发连接及 Token 预算。

## 11. 可观测性

每一次模型调用至少记录：

```text
trace_id
span_id
user_id_hash
session_id
case_id
task_type
agent_name
prompt_version
model_name
knowledge_version
input_tokens
output_tokens
latency_ms
time_to_first_token_ms
status
fallback_reason
estimated_cost
```

请求上下文必须使用 `contextvars`，不能使用当前 `logging.py` 中进程级共享的 `_ContextFilter` 状态。SSE 并发下每个请求的 trace 必须独立。

关键指标：

- 请求成功率和错误率。
- SSE 首 Token P50/P95、完整响应延迟、断开率。
- 模型超时、限流和降级次数。
- RAG 命中率、低证据拒答率、引用支持率。
- 批阅任务成功率、重试次数和教师覆盖率。
- Token 数、预估费用和用户/班级预算。
- 内部回调成功率和延迟。

## 12. 测试和评测

### 12.1 单元测试

- `security.py`：JWT、角色、Token、过期、算法拒绝。
- `session_policy.py`：跨学生访问、已结束会话和病例不匹配。
- `citation_policy.py`：引用版本、页码和证据支持。
- `score_calculator.py`：边界分数、扣分总和和人工覆盖。
- `structured_output.py`：正常 JSON、额外字段、截断和非法值。
- `idempotency_service.py`：重复消息和重复回调。

### 12.2 集成测试

- FastAPI TestClient + fake Spring Client。
- fake Model Gateway，不在测试中调用真实供应商。
- fake Milvus Repository。
- 覆盖成功、超时、限流、空知识库和回调失败。
- SSE 事件顺序和客户端断开。

### 12.3 AI 评测集

`tests/evals/datasets/` 使用 JSONL 保存医学专家标注案例。每条数据包括：

```json
{
  "case_id": "chest-pain-001",
  "student_messages": [],
  "expected_patient_facts": [],
  "forbidden_leaks": ["hidden_disease"],
  "required_citations": [],
  "expected_safety_action": "ALLOW"
}
```

至少评测：

- SP 人设一致性和诊断泄露率。
- 高危信号遗漏率。
- RAG 引用正确率和无证据拒答率。
- Reviewer 错误定位和扣分一致性。
- Evaluator 与专家评分的一致性。
- Prompt Injection、越界诊疗和敏感内容拒答。

真实模型评测不等于单元测试；每次升级模型、Prompt 或知识库版本都应重新运行。

## 13. 依赖与部署

目标依赖：

```text
fastapi
uvicorn
pydantic
pydantic-settings
httpx
PyJWT
sse-starlette
pymilvus
tenacity
redis
litellm                 # 可选，若作为模型网关部署
langgraph               # 只用于 SP Agent 状态编排
haystack-ai             # 若采用 Haystack RAG Pipeline
langfuse                # 可选，自托管观测
deepeval                # 仅开发与 CI 评测环境
```

当前仓库已经使用 `openai` 兼容客户端。目标设计采用 LangGraph、LiteLLM、Haystack、Langfuse 和 DeepEval，但必须通过内部接口隔离；项目在 `requirements.txt` 中固定运行时版本，在单独的开发依赖中固定 DeepEval，并记录仓库、许可证、用途和升级验证结果。

Docker 运行约束：

- FastAPI 使用多个 worker 时，不能依赖进程内存保存教材索引、任务状态或会话状态。
- Redis/Milvus/任务状态必须使用外部服务。
- 不使用 `--reload` 作为生产命令。
- AI 容器不直接暴露内部管理接口给公网。
- `/v1/ai/chat/stream` 配置 Nginx 关闭缓冲并设置合理读超时。
- 模型供应商地址、对象存储地址和 CORS Origin 都由生产环境变量注入。

## 14. 配置清单

### 14.1 必填配置

```dotenv
ENV_MODE=prod
JWT_SECRET=<至少32字节随机强密钥>
AI_INTERNAL_TOKEN=<随机内部服务密钥>
BACKEND_CALLBACK_URL=http://backend:8080
MILVUS_HOST=milvus
MILVUS_PORT=19530
MILVUS_COLLECTION=zhiyu_textbook_v1
CORS_ALLOWED_ORIGINS=https://mobile.example.com
```

### 14.2 模型配置

```dotenv
LLM_BASE_URL=https://provider.example/v1
LLM_API_KEY=<secret>
LLM_MODEL=<model-name>
VISION_BASE_URL=<optional>
VISION_API_KEY=<optional>
VISION_MODEL=<optional>
EMBEDDING_BASE_URL=<provider>/v1
EMBEDDING_API_KEY=<secret>
EMBEDDING_MODEL=<embedding-model>
```

空模型配置只允许在开发或测试环境使用。生产环境应根据功能明确选择“必需模型缺失则不可就绪”还是“该功能进入人工队列”。

### 14.3 Compose 变量映射测试

必须存在一个配置测试，验证：

```text
AI_INTERNAL_TOKEN -> settings.internal_token
ENV_MODE -> settings.env
JWT_SECRET -> settings.jwt_secret
ENABLE_LLM_FALLBACK -> settings.enable_llm_fallback
```

当前项目已经实际暴露过 `AI_INTERNAL_TOKEN` 和 `ENV_MODE` 未映射到 FastAPI 字段的问题，该测试是上线门禁，不是可选优化。

## 15. 现有文件的删除、兼容和迁移规则

### 15.1 不立即删除的文件

以下文件先保留兼容导出，避免 Spring Boot 和已有测试同时断裂：

- `app/api/embed.py`：转发到新的知识入库 Workflow。
- `app/services/llm_client.py`：保留 `llm_client` 兼容名，内部代理 `ModelGateway`。
- `app/services/backend_client.py`：保留旧方法，内部代理 `SpringClient`。
- `app/prompts/templates.py`：标记 deprecated，逐个转发到 PromptRegistry。

兼容模块不能增加新业务逻辑，也不能绕过新鉴权和输出校验。

### 15.2 必须删除的行为

- 任意 PDF URL 下载。
- 生产默认 Token 和默认 JWT 密钥。
- 失败时返回固定批阅分数。
- 只检查 JSON 中一个字段的宽松模型输出。
- 只把引用返回给前端但不把证据放入模型上下文。
- 进程级共享 trace/session 上下文。
- `async` 路由内直接运行长时间同步网络和 Milvus 操作。

## 16. 接手人工作方式

接手后不要先新增一个 Agent 文件。按以下阅读顺序理解系统：

1. 阅读本设计文档的第 3、4、5 节，理解边界和目录。
2. 阅读 `app/domain/schemas/`，先看输入输出契约。
3. 阅读对应 `app/workflows/`，理解业务流程。
4. 阅读 `app/agents/sp_agent.py`，只在需要改变病人行为时修改 Agent。
5. 阅读 `app/services/model_gateway.py` 和 `retrieval_service.py`，理解外部 AI 能力。
6. 阅读 `app/adapters/spring_client.py`，确认业务数据来源和回写接口。
7. 运行单元、集成和评测测试，再修改 Prompt 或模型配置。

修改判断规则：

- 用户权限或业务状态：改 Spring Boot。
- 模型供应商、Prompt 或结构化输出：改 FastAPI。
- 病例内容和标准路径：改教师业务接口/数据库。
- 教材证据：改知识入库和 RAG，不直接改回答文字。
- 正式分数：改量表规则和教师复核，不只改 Prompt。

## 17. 最终验收标准

重构完成后必须全部满足：

- FastAPI 生产启动不会接受默认密钥。
- Vision、Chat、内部接口都有正确的鉴权和资源归属校验。
- AI API 失败不会返回 HTTP 200 的伪成功结果。
- 评分和批阅不会使用固定默认分数。
- RAG 证据实际进入生成上下文，引用可以回溯到教材版本和页码。
- SP Agent 的状态可恢复，消息保存具有幂等性。
- 批阅、报告和知识入库具备任务状态、重试和最终失败状态。
- 模型、Prompt、知识库、病例快照和输出可以通过 `trace_id` 关联。
- 50 路并发 SSE 不阻塞事件循环，断线和重连不会重复写消息。
- 单元、集成、安全和 AI 评测全部通过。
- Spring Boot、Flutter 和 FastAPI 仍使用既有身份与业务边界。
- 接手人只读目录、Schema、Workflow 和本文件，就能定位一次请求的完整路径。

## 18. 本设计不包含的内容

本文件定义的是目标架构和开发约束，不包含以下实施动作：

- 不直接修改现有 Python 业务代码。
- 不替换当前 Spring Boot 数据库模型。
- 不迁移 Vue Web。
- 不承诺任何具体模型供应商或模型效果。
- 不把医学免责声明当成质量保障；真实上线仍需要医学专家、数据保护和安全审查。

在实施前，开发者应把本文件中的接口 Schema、状态枚举、Prompt 版本和评测数据集提交到代码审查，并由医学教学负责人确认评分量表。
