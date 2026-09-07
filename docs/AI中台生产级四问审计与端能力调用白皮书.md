# AI 中台生产级四问审计 · 小白即可读懂的白皮书

> 审计对象：`ai/`（FastAPI AI 中台）+ `backend/`（Spring Boot 业务中台）+ `mobile/`（Flutter 学生/教师端）。
> 审计方法：源码调用链 + 接口契约 + 端到端回归测试。
> 测试基线：AI 中台 `94 passed, 4 skipped in 19.58s`；聚焦回归 `8 passed in 4.57s`。
> 结论口径：**有实现 ≠ 真实模型已验证**；**有接口 ≠ 用户点得到**；**降级 ≠ AI 成功**。

---

## 〇、一句话结论（看完这一节就够了）

你对这四个问题的答案，用大白话说：

| 你的问题 | 答案 | 成熟度 |
|---|---|---|
| ① 是无状态请求吗？ | **是**。每个请求的 trace / 会话 / 采样参数都放在"单次请求私有的协程上下文"里，50 路并发各自独立，不串号。 | ✅ 已达标 |
| ② 是结构化输出吗？ | **是**，AI 返回的 JSON 会被 Pydantic 严格解析校验，不合格就报错。**但"严格模式"只对教师端模型完整开启**，其余模型的校验偏松。 | ⚠️ 基本达标 |
| ③ 是流式响应吗？ | **是真流式**。从大模型 token 逐个吐 → SSE 逐条推 → 手机一行行解析渲染，全程是真实字节流。打字机只是叠加在最上面的皮，不是靠它"假装"。 | ✅ 真流式 |
| ④ 工具调用 / ReAct / Agent 循环成熟吗？ | 工具调用**有真正实现且能用**，但**目前只用在"病例问诊(SP)"这一个场景**；其余 5 个 Agent 都是"一次性直出"，没有用上工具和循环。多模态**只有图像**，**没有音频/视频**。 | 🟡 基础成熟，覆盖窄 |

一句话：**骨架是对的、真流式也是真的，但要到"决赛级"，差别主要在"覆盖面"——绝大多数 Agent 还是"一问一答的管道"，没有把工具、ReAct 循环、多轮自主决策变成默认能力。**

---

## 一、四问逐条详解（带证据，小白也能核对）

### 1️⃣ 无状态请求：✅ 合格，无需修复

**大白话**：无状态 = 服务端不记住"上一个用户"，甲用户问了一天，乙用户开一个新请求，绝对不会看到甲的数据。

**证据（它怎么做到的）：**
- 所有"本次请求才有的东西"——追踪号(trace_id)、会话号(session_id)、Agent 采样参数——都放在 Python 的 **contextvars 协程上下文**里。
  - [logging.py](file:///e:/zhiyu/ai/app/core/logging.py) 第 21-28 行定义了这些 `ContextVar`。协程上下文是"每个请求一个隔离沙箱"，天然不串扰。
- 流式环节最怕"上下文提前被清掉"。网关在 [agent_gateway.py](file:///e:/zhiyu/ai/app/api/agent_gateway.py) 里把采样注入包在**生成器内部**，流结束/异常才清，且只在"本请求自己的任务里"，多路并发互不影响（第 97-110 行）。
- 唯一的"共享内存"是单例里的**运行健康标记**：
  - `llm_client._degraded`、`llm_client._failed_models`（[llm_client.py](file:///e:/zhiyu/ai/app/services/llm_client.py) 第 42-43 行）——记的是"模型是不是挂了"，不是用户数据，跨请求共享是**故意为之**，用于"恢复后补报一次事件"，不泄露任何用户信息。
  - `config_center`（提示词/Agent 参数缓存）、`model_registry`（模型缓存）——只在请求期间**只读**，不写入请求状态。

**要不要修？** 不需要。这是合规的无状态设计。

---

### 2️⃣ 结构化输出：⚠️ 基本合格，但严格模式覆盖不全

**大白话**：结构化输出 = 让 AI 按固定格式（比如"给 5 个维度打分数"）返回 JSON，而不是乱说一句话，程序拿到就能直接用/存库。

**它做了什么（[structured_output.py](file:///e:/zhiyu/ai/app/services/structured_output.py)）：**
- `parse_and_validate(raw_text, Pydantic模型)`：把 AI 的原文里"抠出 JSON"→ `json.loads` → 用 Pydantic 模型 `model_validate` 校验 → 失败抛 `OutputSchemaInvalidError`。
- "抠 JSON"用了三层策略：直接是 JSON → ```json 代码块 → 从第一个 `{` 到最后一个 `}`，每次抠出后还要 `json.loads` 验证合法性，**不是盲切**。
- 学生侧还有 `parse_to_dict`，可校验"必需字段是否齐全"。
- 已用在：教师端的病例草稿/班级洞察/复核/推荐病例/质检/练习题、备课教案/教学指南/合并教案/课件、每日一例评分、作文/大病历批阅、错题分析等一大堆能力，返回前都会过这道校验。

**缺口（要修的点）：**
- 设计文档号称 `extra="forbid"`（多余字段就报错），但实测全项目只有 [teacher.py](file:///e:/zhiyu/ai/app/models/teacher.py) 的模型加了"禁止多余字段"，**其余模型的 JSON 校验模型（review/essay/chat/paper…）都没开严格模式** → 多余字段会被悄悄丢掉，而非报错。后果：模型"多塞了一个字段"你不会发现，长期埋雷。
- 校验是"事后解析"，没有"解析失败自动重试一次"的环节。坏了就直接抛错（后端映射成业务码 5004 `AI_OUTPUT_INVALID`，前端需要自己降级）。
- 没用模型供应商原生的 `response_format=json_object` 强制 JSON，兼容性更好但少了模型侧兜底。

**建议**：给所有"AI 直接产出"的 Pydantic 模型统一补 `model_config = ConfigDict(extra="forbid")`；给结构化解析失败加"一次自动重试"。这个我可以直接帮你改。

---

### 3️⃣ 流式响应：✅ 是真的 token 级流式，不是打字机糊弄

**大白话**：真流式 = 大模型"每吐一个字"就立刻经网络送到你手机，你看着它一个字一个字蹦出来；假流式 = 服务端憋半天一次性返回整段，手机再自己一个字一个字演。

**代码级的证据链（每一环都是真流式）：**
1. **模型侧**：[llm_client.py](file:///e:/zhiyu/ai/app/services/llm_client.py) 第 132-190 行 `stream()`，`yield delta` 逐个 token 往外吐；还支持 `stream_options.include_usage` 拿用量，兼容不了就自动降级但流不变。
2. **编排侧**：[consultation_graph.py](file:///e:/zhiyu/ai/app/workflows/consultation_graph.py) `sp_reply` 节点 `async for delta in sp_reply_stream_with_tools(...): await _emit("message", {delta})`，每个增量发一条 SSE。
3. **网关侧**：[chat.py](file:///e:/zhiyu/ai/app/api/chat.py) 第 34-50 行 `EventSourceResponse(...)`，`/internal/chat/stream` 用 SSE 一条条转发。
4. **手机侧（关键反证）**：[student_api.dart](file:///e:/zhiyu/mobile/lib/features/student/data/student_api.dart) 第 476-495 行用的是 `utf8.decoder.bind(rs.stream).transform(const LineSplitter())` 逐行解析 `event:` / `data:`，收到一条 `message` 事件就 `yield` 一个增量，`event == 'done'` 才结束。
   - 也就是手机是**真的在边收边渲染**，`typewriter_text.dart` 只是渲染时的一个"打字机"皮肤，做的是珠上叠花。

**所以**：除了打字机皮肤，下面还有一整条真流式铁路。这条不是假的。

---

### 4️⃣ 工具调用 / ReAct / Agent 循环：🟡 基础扎实，但覆盖只有"问诊"一个场景

**大白话分解：**
- **工具调用（function calling）**：让 AI 在回答前主动"去查一下教材/确认检查"。**有真实现**：
  - [toolkit.py](file:///e:/zhiyu/ai/app/agents/toolkit.py) 定义了 `search_textbook`（查教材知识库 RAG）、`report_exam_result`（SP 按病例清单确认某项检查，绝不编造数据）。
  - [llm_client.py](file:///e:/zhiyu/ai/app/services/llm_client.py) `resolve_tools()`（第 288-361 行）：模型返回 `tool_calls` → 执行工具 → 把结果按 `tool` 角色回填 → 继续问模型，最多循环 `max_steps`（默认 3）轮直到模型不再要工具。**这就是一个标准的 ReAct 式循环**。
  - 它在走 ReAct 时还给工具做"显示级引用"过滤，防止教材检索到别的病种乱入（[consultation_graph.py](file:///e:/zhiyu/ai/app/workflows/consultation_graph.py) `_display_safe`）。
- **Agent 编排图（LangGraph）**：病例问诊用的是**真·状态机图** `load_context → safety_check → rag_search → exam_dispatch → sp_reply → output_check → persist → mentor_update`，带条件分支（会话非法/安全拦截直接结束），是官方 LangGraph `StateGraph` 编译出来的。

**但不成熟的地方（这才是成长空间）：**
1. **覆盖面窄**：工具+ReAct 循环目前只挂在了 **SP 病例问诊** 这一个 Agent 上。其余 5 组（导师/评测批阅/学习教练/教师助手/陪伴）全是 `STRATEGY_CODE`，即"一次性直出"的管道，**没有工具调用、没有多轮循环、没有 graph 编排**。
2. **策略字段还没真正生效**：配置中心声明了 `CODE / GRAPH / TOOL / LOOP` 四种策略（[config_center.py](file:///e:/zhiyu/ai/app/services/config_center.py) 第 34-41 行），数据库也能下发 `strategy/maxIterations/stopCondition`，但**没有任何一个 Agent 实际按配置切到 LOOP/TOOL 策略去驱动**——循环能力是硬编码在 `resolve_tools` 里，而不是由配置驱动的工作流。`resolve_agent_spec` 只是解析了字段，没有据它分发到不同的执行器。
3. **没有统一的 Agent 基类**：约定的 `BaseAgent` 抽象没有落地为代码，现在各 Agent 是"模块 + 各自娘胎里的流程"，重复逻辑靠复制，扩展新 Agent 时需要手工照旧样写。

**一句话**：工具/ReAct/循环的"地基"是有的、能用的、也测试过的，但**还没有成为所有 Agent 的默认肌肉**，这是从"样机"到"比赛一等奖"最关键的一段距离。

---

### 5️⃣ 多模态：🟠 只有图像，无音频/视频

- ✅ **图像**：
  - 上传影像/化验单做 AI 解读：[vision.py](file:///e:/zhiyu/ai/app/api/vision.py) `/v1/ai/vision/analyze`，走 VLM（视觉大模型），图片 URL 有 SSRF 防护（禁 localhost/内网）。学生问诊里可"圈画/上传图片"由 `StudentSessionServiceImpl.analyzeImage` 调它。
  - 教材带图 → 自动生成"图述"喂给病例上下文（[consultation_graph.py](file:///e:/zhiyu/ai/app/workflows/consultation_graph.py) `rag_search` 里的 `image_caption_enabled`，靠 `image_index_service` VLM 看图说话）。
- ❌ **音频**：全库搜不到任何 TTS（文转音）/ ASR（音转文）/ 语音调用——**没有**。
- ❌ **视频**：没有。

**结论**：多模态 = 图像。如果你大赛大纲里有"语音交互/朗读病例"之类，这块是 0，要补。

---

## 二、各端·各功能调用清单（谁调谁、怎么调）

> 口诀：**所有 AI 都收敛到 6 个"Agent 分组"**，调用的统一方式是后端发 `POST /internal/agent/{分组}`，请求体就三件套 `{action, task, options}`。
> 手机/教师端 → 业务中台(Spring) → `XxxClient` → `POST /internal/agent/{分组}` → AI 中台 → 模型。

### 6 个 Agent 分组与可用 action

| 分组 code | 分组名 | 场景 | 可用 action（动作） |
|---|---|---|---|
| `consultation` | 问诊咨询 | 学生问诊室 | `stream`(流式) / `sync`(同步) / `opening`(开场白) |
| `mentor` | 导师 | 学生复盘思维树/苏格拉底提示 | `update_tree` |
| `evaluator` | 评测批阅 | 批阅+评分 | `medical_record` / `essay` / `session` / `daily_case` |
| `coach` | 学习教练 | 个性化学习 | `learning_path` / `recommend_weakness` / `mistake_analyze` / `weakness_diagnosis` / `paper_generate` / `alert` |
| `teacher` | 教师助手 | 教师生成/备课 | `case_draft` / `class_insight` / `review_assist` / `recommend_cases` / `quality_check` / `practice_questions` / `lesson_design` / `lesson_guide` / `lesson_merge` / `lesson_ppt` |
| `companion` | 陪伴 | 学伴对话 | `sync` / `stream`(流式) |

### 调用示例（怎么发）

```http
POST /internal/agent/consultation
X-Internal-Token: <内部令牌>
Content-Type: application/json

{
  "action": "stream",          // 在这个分组里选"流式问诊"能力
  "task": { "sessionId": 101, "caseId": 7, "messages": [{"role":"student","content":"我胸痛"}] },
  "options": { "stream": true } // 告知性信号：写 true 且动作是流式，写错会立刻 400
}
```

前端各端怎么用（按你关心的端）：

| 端 | 怎么调用 | 拿到什么 |
|---|---|---|
| 学生移动端 | 走后端 `/api/v1/student/sessions/{id}/chat/stream`，SSE 逐字收 `message` 事件；学伴走 `/api/v1/student/companion/stream` | 真流式对话 + 引用/报告卡/阶段/安全拦截事件 |
| 学生单测/调试 | AI 中台加**鉴权能省**的联调口：`/v1/ai/chat/stream`、`/v1/ai/companion/stream`（学生 JWT）；内部便捷口 `/internal/chat/sync`、`/internal/companion/sync` | 同上，同步聚合版 |
| 教师端 | 走 `backend` 的 `TeacherClient` / `EvaluatorClient` → `/internal/agent/teacher`（教案/病例/质检/批阅）等，均为同步 JSON | 结构化结果（Pydantic 校验过） |
| 管理端 | 不直连 AI；配置"提示词/Agent 参数/模型/RAG"的下发与热更新 | 配置中心 → 30s 热生效 |

---

## 三、完成度对照（结合大赛大纲）

| 大赛关注点 | 现状 | 完成度 |
|---|---|---|
| 知识问答 + RAG 引用 | 主链路通、有引用分级与显示门槛 | 🟢 基本完成 |
| 病例问诊(SP) + 工具/ReAct/图 | **全项目最完整**：真流式+真 ReAct 工具+LangGraph 图 | 🟢 完成度高 |
| 大病历/作文批阅 | 结构化评分、AI/教师二元来源、置信度展示待补 | 🟡 业务闭环，展示待补 |
| 每日一例 | 有闭环、失败有 `evaluated=false` 不错方向 | 🟢 基本完成 |
| 个性化学习路径/错题推荐 | 接口在，但**缺学生历史/错题事实输入** | 🟡 未形成用户闭环 |
| 教案/课件备课 | **最适合打比赛 Demo** | 🟢 最完整 |
| 多模态 | 仅图像（影像解读+教材图述） | 🟠 缺音频/视频 |
| Agent 体系 | 6 分组网关已收敛；策略/工具/循环未全量启用 | 🟡 覆盖窄 |

---

## 四、建议改进清单（按优先级）

1. **P0｜root Cause 是"覆盖面"**：把工具调用 + ReAct 循环从"只有问诊"推广到导师/教练/教师多个 Agent；真正落地"策略字段驱动执行器"（现在字段只解析不分发）。
2. **P1｜结构化严格模式统一**：给所有 AI 输出模型补 `extra="forbid"` + 解析失败自动重试一次。
3. **P1｜统一 Agent 基类**：把现在靠复制粘贴的 Agent 流程收敛成可复用模板，否则每个新能力都要重写一套。
4. **P2｜多模态扩音/视频**：若大纲要求语音交互则需 TTS/ASR。
5. **P2｜个性化推荐接真实学情**：把学生历史答题/错题喂进学习路径，别用"内科常见薄弱点"通用话术。

---

*来源与核验：AI `94 passed, 4 skipped`；Spring 端 `mvn compile` 通过。本项目 cookiecutter 式结论：实现不等于线上验证，真流式不等于所有 Agent 都用上了工具。*