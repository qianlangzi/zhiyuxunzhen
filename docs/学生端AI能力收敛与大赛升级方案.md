# 智愈寻真 · 学生端 AI 能力收敛与大赛升级全面解决方案

> 版本：v1.0（2026-08-26）
> 依据：2026-08-26 对 `ai/`、`backend/`、`mobile/` 的实读审计 + 真实端到端调用验证 + 大赛题目要求
> 定位：作为「优化与升级」的**执行蓝图**，每项改动给出目标、改动点、验收标准，可直接排期落地

---

## 〇、结论速览（TL;DR）

1. **AI 能力分散**是真实存在的结构问题：AI 被按「接口」切碎成 10+ 个触点散落在各页面，强功能自成闭环、弱功能点到即止，缺一条贯穿主线。→ **收敛为「角色身份 + 主线闭环」**（教练 / 学伴 / SP / 评估四类有身份的 AI 能力）。
2. **要不要封装 Agent**：要，但**精准做**——系统已有 5 个 Agent + 4 条 LangGraph workflow + 工具层，不是从零建；重点是把「伪 AI」（学习路径、错题本、薄弱点）升级成真 Agent，并补**可观测性**（trace / 工具轨迹 / 版本）。
3. **是否符合大赛要求**：骨架扎实、核心闭环通，但「个性化 / 学习陪伴 / 多模态 / 真实用户数据」四个评分点有明显空窗，其中前两项恰恰是「助学」赛道最易出亮点之处。
4. **还需新增什么**：P0 补断点（学习路径闭环、错题 AI 归因）→ P1 出亮点（AI 学伴、问教材、多模态知识库）→ P2 差异化（学习档案、CMB 评测、可追溯证据、真实用户数据）。

---

## 一、现状盘点（事实基线，非推测）

### 1.1 系统运行态（2026-08-26 实测）

| 项目 | 状态 | 说明 |
|---|---|---|
| 容器 | 9/9 运行中 | backend / ai / ai-worker / milvus / mysql / redis / minio / etcd / mmore |
| AI 服务就绪 | ✅ READY | LLM / Embedding / Milvus 全部 available，未降级 |
| 模型热切换 | ✅ 4/4 激活 | LLM(deepseek-chat) / VISION(qwen3-omni-flash) / EMBEDDING(BAAI/bge-m3) / EMBEDDING_MULTI(qwen3-vl-embedding)，存 `ai_model` 表 |
| 教材向量库 | ✅ 381 条 | Milvus 已入库，实测检索返回带章节/页码溯源 |
| AI 讲解链路 | ✅ 端到端可用 | student01 登录 → 后端 → AI → LLM 讲解 + 5 条 citation，非降级 |
| 全局检索 | ✅ 端到端可用 | 教材/题/病例混合检索，返回溯源 |

### 1.2 学生端功能全景（最新代码，非过时报告）

| 功能 | 页面 | AI 深度 | 现状 |
|---|---|---|---|
| SP 问诊 + 思维树 + 影像读图 | [chat_room_screen.dart](mobile/lib/features/student/chat/chat_room_screen.dart) | 🟢 深 | LangGraph 编排，最硬资产 |
| OSCE 四维评估 | [osce_result_screen.dart](mobile/lib/features/student/result/osce_result_screen.dart) | 🟢 深 | Evaluator Agent |
| AI 讲解（知识问答） | [ask_screen.dart](mobile/lib/features/student/ask/ask_screen.dart) | 🟢 深 | RAG 溯源，实测可用 |
| 每日一例 | [daily_case_screen.dart](mobile/lib/features/student/daily_case/daily_case_screen.dart) | 🟢 深 | LLM 判题 + 溯源 |
| 复盘报告 + PDF | [review_report_screen.dart](mobile/lib/features/student/report/review_report_screen.dart) | 🟢 深 | AI 生成 + 本地 PDF |
| 个性化推荐 | [recommendation_screen.dart](mobile/lib/features/student/recommend/recommendation_screen.dart) | 🟡 中 | **已接真实薄弱点 + AI 建议**（后端先算薄弱度再喂 AI） |
| 全局搜索 | [search_result_screen.dart](mobile/lib/features/student/search/search_result_screen.dart) | 🟡 中 | 混合检索，无对话式讲解 |
| 基础题刷题 | [question_*](mobile/lib/features/student/training/) | 🟡 中 | 客观题判题 |
| 教材中心 + PDF 阅读 | [textbook_center_screen.dart](mobile/lib/features/student/textbook/) | 🟡 浅 | 只能阅读/检索 |
| 错题本 | [mistakes_screen.dart](mobile/lib/features/student/mistakes/mistakes_screen.dart) | ⚪ 无 | 纯 DB 记录，**无 AI 归因** |
| 学习路径 | 接口存在（[student_api.dart](mobile/lib/features/student/data/student_api.dart#L275) 有 `generateLearningPath`） | 🔴 断点 | **无页面调用 + AI 端无真实薄弱数据** |
| 学习热力图 | home | ⚪ 无 | 纯统计 |
| 作业/任务/班级 | 各页面 | ⚪ 无 | 业务闭环 |

> 注：这里与 08-22 差距报告的口径差异——「AI 讲解缺失」「环境降级」两项已修复，本方案以最新状态为准。

### 1.3 三层调用链现状

```
Flutter 学生端（按页面散点调用 10+ 接口）
   │ JWT
   ▼
Spring Boot 业务中台（AiPlatformClient 统一转发 + internal-token）
   │ HTTP 回调
   ▼
FastAPI AI 中台（5 Agent + 4 Workflow + RAG + SSE）
   ▼
DeepSeek LLM │ Qwen3-VL VLM │ Milvus │ MySQL │ Redis
```

### 1.4 现有 Agent / Workflow 架构盘点

**Agent（`ai/app/agents/`）**：

| Agent | 职责 | 形态 | 判断 |
|---|---|---|---|
| `sp_agent` | 扮演标准病人，流式 + 工具调用 | 真 Agent（支持 tools） | 保留强化 |
| `tutor_agent` | 知识讲解导师，RAG + 流式 | 单步 LLM + RAG | 保留强化 |
| `reviewer_agent` | 大病历 5 维批阅 | 单步 LLM JSON | 保留 |
| `evaluator_agent` | 会话/OSCE 评估打分 | 单步 LLM JSON | 保留 |
| `mentor_agent` | 思维树 + 苏格拉底引导 | 单步 LLM JSON | 保留 |
| `toolkit.py` | 工具注册（`SearchTextbookTool`） | 工具层 | 扩展 |

**Workflow（`ai/app/workflows/`）**：`ask_workflow`（安全→RAG→讲解→done）、`chat_workflow`（SSE 容器）、`consultation_graph`（问诊图：load→safety→rag→sp_reply→check→persist→mentor）、`sp_graph`。

**诊断**：真正多步编排只有「问诊」一条；其余多为「提示词 + 单次 LLM 调用」的参数化 Agent，且**不可观测**（无工具轨迹/版本/失败重试）。

---

## 二、问题一：AI 能力分散——根因与收敛方案

### 2.1 根因分析

1. **按接口切分而非按角色切分**：每个页面各自接一个小 AI 接口（ask / chat / vision / daily_case / recommend / learning_path / evaluate…），没有统一的「AI 能力注册表」。
2. **AI 参与深度参差**：深的功能（SP 问诊）自成闭环，浅的功能（错题本 0 AI、教材中心仅阅读）只是点缀，造成「哪里都有又哪里都没有」。
3. **缺主线**：学生的「学情诊断 → 路径规划 → 推荐 → 巩固」本应是一条链，但薄弱点（统计公式）、路径（断点）、推荐、错题（无归因）彼此独立。
4. **同能力多入口**：教材相关被拆成「检索 / 阅读 / 讲解 / 推荐溯源」多处，无统一入口心智。
5. **可观测性缺失**：用户看到结果但看不到「证据链」，AI 价值感弱。

### 2.2 收敛策略：从「接口散点」到「角色身份 + 主线闭环」

把学生端 AI 收敛为 **4 个有身份的能力**（内部是 Agent，对外是功能入口）：

| 学生视角身份 | 底层 Agent | 承载功能 | 主线角色 |
|---|---|---|---|
| **AI 学伴/教练**（「我的 AI 导师」） | 学习教练 Agent + 错题归因 Agent + 学情诊断 Agent | 学习路径、个性化推荐、错题归因、薄弱点诊断 | **主线入口** |
| **AI 问诊**（模拟诊室） | SP Agent + Mentor Agent | SP 问诊、影像读图、思维树 | 训练闭环 |
| **AI 讲解**（问教材） | Tutor Agent | 知识问答、概念辨析、指标解读 | 助学支撑 |
| **AI 评估**（复盘） | Evaluator Agent + Reviewer Agent | OSCE、复盘报告、批阅 | 评价闭环 |

**主线闭环**（一句话讲给评委）：`AI 问诊/刷题 → 错题落库 → AI 归因 → 薄弱点诊断 → 学习路径 → 个性化推荐 → 再训练`。

### 2.3 学生端首页信息架构建议

现有首页已较完整（问候/热力图/检索/AI 讲解/任务/推荐/病例/教材/基础题/成长行）。建议在首页增加一个**「我的 AI 导师」主入口卡片**（聚合：学习路径 / 薄弱点诊断 / 错题归因 / 每日推荐），让「主线」在用户界面上可见；其余入口保持，形成「一个导师 + 三个训练场景（问诊/讲解/刷题）」的心智。

---

## 三、问题二：Agent 封装方案（结论：做，但精准做）

### 3.1 决策结论

- **不做**「为 Agent 而 Agent」的全面重构——现有 5 Agent + 4 Workflow 已是骨架，全重写风险大、收益低。
- **做**三件事：① 保留强化强 Agent；② 把「伪 AI」升级为真 Agent（学习路径、错题、薄弱点）；③ 统一编排层 + 可观测性。
- **对外不暴露「Agent」术语**，用户看到的是「AI 导师 / 学伴 / 讲解」这类功能身份。

### 3.2 保留强化清单

| Agent | 强化点 |
|---|---|
| SP Agent | 补充工具调用轨迹记录；结束条件 / 费用规则做成可观测事件 |
| Tutor Agent | 支持「追问上下文 + 指标解读模板」，返回引用结构标准化 |
| Evaluator / Reviewer / Mentor | 输出附加 `confidence` / `evidence` / `missingEvidence` 字段，供前端「可解释」展示 |

### 3.3 新增 Agent 设计

#### ① 学习教练 Agent（把 learning_path 从断点变闭环）

- **输入（必须来自业务中台事实快照，禁止只发 studentId）**：薄弱知识点及分数、近期错题要点、已学章节、任务完成率、候选教材/题（防幻觉）。
- **输出**：`diagnosis`（知识水平诊断）→ `pathSteps[]`（知识点诊断 → 教材复习 → 简单病例 → 标准病例 → 综合病例的递进路径）→ 每步 `goal` / `evidence` / `targetMetric`。
- **实现**：`ai/app/api/learning_path.py` 改为调用业务中台 internal 接口（`/api/internal/student/{id}/learning-facts`，新增）拉取事实快照 → 组装给 LLM；后端 `LearningPathController` 已取 studentId，需补充事实聚合服务。

#### ② 错题归因 Agent（把错题本从记录变辅导）

- **输入**：错题（题目 + 学生答案 + 标准答案 + 错误类型：诊断/漏问/检查/文书/沟通）。
- **输出**：`rootCause`（为什么错、缺哪个知识点）→ `explanation`（通俗讲解）→ `recommendedTags[]` → `practiceHint`（巩固题方向）。
- **实现**：新增 `ai/app/agents/mistake_agent.py` + `ai/app/api/mistake_analysis.py`（`/internal/mistake/analyze`）；后端在错题列表接口返回时批量附带归因（或按需异步生成 + 缓存）；移动端错题本新增「AI 归因」展开卡片。

#### ③ 学情诊断 Agent（把薄弱点从统计公式变 AI 诊断）

- **现状**：`WeaknessAnalysisService` 用时间衰减 + 正确率公式算薄弱度（可靠但非 AI）。
- **升级**：保留统计兜底，叠加 AI 归因——按知识点聚合错题 → LLM 输出「薄弱根因 + 优先级排序 + 建议」，与统计分数合并展示（`source: STAT + AI`）。
- **实现**：复用错题归因 Agent 的聚合能力，新增 `/internal/diagnosis/weakness`，前端推荐页展示「AI 诊断」区块。

### 3.4 统一编排层与可观测性（P0 级）

参考审计报告 P0 项，统一响应契约与证据链：

```json
{
  "status": "SUCCESS | DEGRADED | FAILED | PENDING",
  "source": "LLM | RULE | CACHE | STAT | NONE",
  "degraded": false,
  "traceId": "...",
  "evidence": { "model": "...", "promptVersion": "...", "agent": "...", "ragVersion": "..." },
  "citations": [],
  "data": {}
}
```

- 所有 Agent 调用打 `traceId`，记录工具轨迹（调用了哪些工具、耗时、重试）。
- 降级（RULE / CACHE）**必须**显式标记，禁止 fallback 冒充成功；降级结果不得写入正式成绩/报告。
- 管理端 AI 配置中心增加「最近请求 + 版本回滚」证据查看（对应已建 `ai_model`/`ai_prompt`/`ai_agent`/`ai_runtime_config` 表）。

### 3.5 Agent 化改造步骤

1. 新增 2 个 Agent 文件 + 3 个 internal API（学习教练 / 错题归因 / 学情诊断）。
2. 后端新增 1-2 个 internal 事实快照接口 + 2 个学生端 API（路径、归因）。
3. 移动端：新增「我的 AI 导师」页（路径 + 薄弱 + 归因 + 推荐），错题本加归因卡片，推荐页加诊断区块。
4. 接入 trace/证据链，管理端可回放。

---

## 四、问题三：大赛要求对照与差距清单

### 4.1 大赛评分项逐项对照

| 评分维度 | 当前判定 | 冲刺第一名证据（要做的） |
|---|---|---|
| 垂直学科知识库 | 🟢 部分满足 | 展示真实教材来源、分片/向量统计、召回命中与引用（已有 381 向量，补「知识库看板」） |
| RAG | 🟢 工程具备 | 补召回前后对比、引用覆盖率、离线评测集（补评测脚本） |
| 智能体编排 | 🟡 部分满足 | 展示 Agent 状态机、工具调用轨迹、失败重试（做可观测后即可展示） |
| 多模态 | 🟡 部分满足 | 影像读图 + 检索引用 + 病例决策链路；**MMore 多模态知识库接入生产**（杀手锏） |
| 可追溯/可解释 | 🟡 部分满足 | 每个答案关联 trace/模型/提示词/Agent/RAG 版本与证据片段 |
| 模型微调/优化 | 🔴 空窗 | CMB 医学评测集脚本 + 模型 A/B 指标（数据集已登记，实际使用为 0） |
| 个性化与自适应 | 🔴 **不足** | 学习路径真实化（断点）+ 学情诊断 Agent + 路径完成反馈闭环 |
| 学习陪伴 | 🔴 **空窗** | 错题 AI 归因 + 独立 AI 学伴入口 |
| 复杂问题分析 | 🟢 有潜力 | 跨病例/检查/教材/评分量表的一条完整 Demo |
| 真实用户数据 | 🔴 未收集 | 试用记录、任务完成率、满意度、准确率、延迟（需埋点+反馈入口） |

### 4.2 学生端（助学赛道）差距明细

| 大赛要求 | 现状 | 判定 |
|---|---|---|
| 学习路径规划（诊断→动态路径→资源） | AI 端无真实薄弱数据 + 无页面 | 🔴 断点 |
| 知识问答与讲解（分步、可追溯） | 已有 AI 讲解（ask），缺「教材常驻问答入口」心智 | 🟢 接近达标 |
| 学习过程陪伴（错题归因、策略优化） | 无归因、无独立学伴 | 🟠 缺失 |

---

## 五、问题四：功能新增/升级清单（P0 / P1 / P2）

> 每个条目包含：**目标 / 改动点（涉及文件）/ 验收标准**。涉及「AI」与「非 AI」均列出。

### 🔴 P0 补断点（决定演示可信度，优先做）

| # | 功能 | 类型 | 改动点 | 验收标准 |
|---|---|---|---|---|
| P0-1 | **学习路径真实化** | AI + 非 AI | `ai/app/api/learning_path.py` 拉业务中台事实快照；后端新增 `/api/internal/student/{id}/learning-facts` + 学生端路径接口；移动端新增「学习路径」页（递进步骤 + 溯源） | 输入 student01 可生成基于**本人错题/薄弱点**的递进路径，每步带教材溯源；前后端数据闭环 |
| P0-2 | **错题 AI 归因** | AI | 新增 `mistake_agent.py` + `/internal/mistake/analyze`；后端错题接口附归因（异步+缓存）；移动端错题本加归因卡片 | 每条错题显示「根因 + 讲解 + 巩固方向」，含 source/status |
| P0-3 | **薄弱点 AI 诊断** | AI | 新增 `/internal/diagnosis/weakness`，统计兜底 + AI 归因合并；推荐页展示「AI 诊断」区块 | 薄弱点卡片显示 STAT + AI 双重来源，可追溯 |

### 🟠 P1 大赛亮点（助学赛道命中率最高）

| # | 功能 | 类型 | 改动点 | 验收标准 |
|---|---|---|---|---|
| P1-1 | **「我的 AI 导师」主入口** | 非 AI + AI | 首页新增主卡片，聚合 路径/薄弱/归因/推荐；统一 4 身份心智 | 首页主线可见，一键进入个人 AI 辅导 |
| P1-2 | **AI 学伴（独立于 SP 病人）** | AI | 新增 `/internal/companion/chat`（闲聊式学伴 + 策略建议，角色区别于 SP）；移动端独立入口 | 学生可与学伴问答，学伴能引用其错题/进度给建议 |
| P1-3 | **「问教材」常驻入口** | AI + 非 AI | 教材中心嵌入 ask 入口（概念辨析/指标解读），返回结构标准化 + 溯源；可加追问上下文 | 在教材阅读页直接提问，返回带章节/页码溯源 |
| P1-4 | **多模态医学知识库** | AI | `experiments/mmore` 的 PDF→图片→VLM 图注管线接入生产 RAG（新增图片分片集合）；学生可「检索影像 + 看图注讲解」 | 检索「心电图」返回影像 + 图注 + 教材引用；检索命中率对比（已有实验数据支撑） |
| P1-5 | **可追溯证据展示** | 非 AI | 学生端答案/推荐旁展开「证据层」：模型/Agent/版本/引用片段 | 每个 AI 结果可展开证据链，评审可回放 |

### 🟡 P2 差异化与产品完整度

| # | 功能 | 类型 | 改动点 | 验收标准 |
|---|---|---|---|---|
| P2-1 | **学习档案/目标管理** | 非 AI | 学生个人页：设定目标、进度追踪、训练统计、连续天数 | 学生端有「我的学习档案」，数据真实持久 |
| P2-2 | **CMB 医学评测展示** | 非 AI | 写评测脚本（`datasets/CMB`），展示模型医学 QA 准确率 | 管理端/材料中呈现量化指标 |
| P2-3 | **用户反馈 + 试用数据埋点** | 非 AI | 内嵌「体验反馈」入口 + 关键动作埋点（完成率/满意度/延迟） | 可导出真实用户数据，支撑「用户认可度」评分 |
| P2-4 | **AI 组卷（学生自测）** | AI | 基于题库 + 知识点 + 难度生成练习卷，学生一键自测 | 学生可生成个性化自测卷 |
| P2-5 | **主观题批改扩展（简答/论述）** | AI | Reviewer 从「大病历」扩展到简答/论述，结构化评分依据 | 教师端可批阅主观简答题 |

---

## 六、落地路线图

| 阶段 | 内容 | 交付物 | 建议顺序 |
|---|---|---|---|
| **阶段 1：闭环补全（P0）** | 学习路径真实化、错题归因、薄弱诊断 | 3 个 AI 接口 + 2 个后端接口 + 2 个新页面 + 证据链契约 | 先 P0-1（主线）再 P0-2/P0-3 |
| **阶段 2：亮点建设（P1）** | AI 导师主入口、AI 学伴、问教材、多模态知识库、证据展示 | 首页改版 + 学伴入口 + 多模态集合 + 证据层 | 先 P1-1（入口可见）再 P1-4（多模态杀手锏） |
| **阶段 3：差异化（P2）** | 学习档案、CMB 评测、反馈埋点、组卷、主观批改 | 档案页 + 评测脚本 + 埋点 + 组卷接口 | 按时间取舍 |
| **阶段 4：大赛材料** | Demo 剧本（主线一条龙）、评分证据包、用户试用记录 | 可回放演示 + 量化指标 | 贯穿始终 |

**主线 Demo 剧本（建议）**：学生刷题/问诊 → 出错落错题本 → AI 归因「缺 X 知识点」→ 生成学习路径（教材章节 + 简单病例 + 综合病例）→ 完成路径后薄弱点下降 → 复盘报告对比前后。评委看到的是「AI 贯穿教与学的系统」，而非点状功能。

---

## 七、风险与注意事项

1. **技术风险**：多模态知识库接入生产需处理图片向量集合与现有 381 向量文本集合的检索融合；VLM（qwen3-omni-flash）为**付费模型**，批量图注消耗阿里 MaaS 配额，建议限量跑 + 结果持久化缓存。
2. **数据/合规风险**：学生事实快照接口需做**越权校验**（只能查本人）；降级结果禁止写入正式成绩/学习掌握度；错题归因/路径建议属于「辅助建议」，明确非诊疗结论。
3. **演示风险**：所有 AI 演示必须**真实 provider 验证**（本项目已实测核心链路可用）；避免展示「降级文案」当成功；准备离线兜底但演示主路径走真 AI。
4. **工程风险**：当前 Spring 测试存在编译断裂（审计报告指出），改造前先恢复测试基线，避免回归。
5. **范围控制**：不要贪多。守住「SP 问诊 + 大病历批阅 + 错题→薄弱→路径→推荐」主线，P0/P1 优先，P2 按时间取舍。
