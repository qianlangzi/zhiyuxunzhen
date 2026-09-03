# AI 中台全方位审计与大赛冲刺整改报告

> 审计范围：`ai/` FastAPI AI 中台、`backend/` Spring Boot 业务中台、`mobile/` Flutter 用户端、`front/src/admin/` 管理端。  
> 审计方式：源码静态调用链、接口契约、配置热同步逻辑、用户入口检索、现有测试结果。  
> 结论口径：**已实现**不等于真实 Provider 已验证；**有接口**不等于用户链路闭环；**降级**不等于 AI 成功。

## 一、结论先行

你的项目已经具备“学科垂类教学 AI 平台”的骨架，不是空壳：有知识库/RAG、模型网关、提示词、Agent 元参数、病例问诊、教师批阅、教案生成、班级洞察、个性化推荐和视觉分析等能力。

但按大赛评审和真实用户体验看，当前更准确的定位是：**功能面较完整的工程样机，核心闭环与可验证性尚未达到决赛第一名级别**。最大风险集中在四件事：

1. 管理端能保存配置，但不能让开发者清楚知道“哪一个版本、何时、是否成功、被哪次请求实际使用”。
2. 多个 AI 结果失败后仍返回看似正常的业务结构，容易把规则 fallback 或空结果误认为 AI 已完成。
3. 个性化学习路径没有学生历史/错题事实输入；教材嵌入和部分能力只有客户端方法，没有真实入口。
4. 当前工作区测试并不干净：AI `60 passed, 1 failed`；Spring Maven 测试在 testCompile 阶段失败，说明现有改动尚未形成可持续回归基线。

## 二、能力与链路矩阵

| 能力 | AI 中台入口 | Spring 调用/落点 | Flutter/管理端入口 | 当前判断 |
|---|---|---|---|---|
| 知识问答 + RAG 引用 | `/internal/ask/sync`、`/internal/ask/stream` | `AiPlatformClient.askSync/askStream`、学生问答控制器 | 学生问答页 | **主链路已接通**，需验证真实向量库、引用质量和流式断线恢复 |
| SP 病例问诊 | `/internal/chat/sync`、会话评估归档 | `StudentSessionServiceImpl.chat/finish`，归档回调落库 | 学生问诊室 | **主链路已接通**，结束时 AI 失败会被吞掉，结果可长期停留在未归档状态 |
| 医学影像/检验多模态 | `/v1/ai/vision/analyze` | `StudentSessionServiceImpl.analyzeImage` | 问诊室上传/圈画 | **入口已接通**，未配置时返回降级成功结构；`citations=[]`，没有视觉结果溯源 |
| 大病历 AI 批阅 | `/review/medical_record`、回调 | 批阅服务、`reviewCallback` 落库 | 教师批阅 | **有业务闭环**，应展示 AI/教师来源、版本和置信度 |
| 每日一例评估 | `/daily_case/evaluate` | `DailyCaseServiceImpl` 保存提交结果 | 学生每日一例 | **有闭环**；AI 失败时 `evaluated=false`，这是正确方向，但需统一错误状态模型 |
| 学习路径 | `/learning_path/generate` | `LearningPathController` | 仅有 API/service，未发现页面调用 | **接口存在但未形成用户闭环**；AI 只收到 studentId 和“内科常见薄弱点”通用提示 |
| 错题补救推荐 | `/internal/recommend/weakness` | `StudentRecommendServiceImpl`，10 分钟内存缓存 | 学生推荐页 | **已接通**；fallback 仍以成功数据返回，必须带 `source/status/degraded` 并禁止写入正式成绩 |
| 教材知识库嵌入 | `/embed/textbook` | `AiPlatformClient.embedTextbook` | 未发现业务调用者 | **孤立能力**；管理端教材上传不能据此证明已入库，需异步任务、进度和失败重试 |
| 教师病例草稿/质检/练习题 | `/case/draft`、`/case/quality_check`、`/case/practice_questions` | `TeacherAiServiceImpl` | 教师病例市场/配置页 | **入口已接通**，需保证生成内容必须人工确认后才能发布 |
| 教师复核辅助 | `/review/teacher_assist` | `TeacherAiServiceImpl.reviewAssist` | 教师批阅页 | **已接通**，已看到实例归属校验；仍应禁止 AI 建议直接覆盖成绩 |
| 班级学情洞察 | `/insight/class`、`/insight/alert` | 教师 Dashboard/告警服务 | 教师端 | **部分接通**；数据聚合依赖已有批阅和错题事实，需显示统计时间窗和样本量 |
| 智能备课 | `/lesson/design`、`/lesson/guide`、`/lesson/merge` | `TeacherLessonServiceImpl` | 备课列表、向导、详情 | **目前最适合做比赛 Demo**；应补充教材引用、版本对比和人工确认发布 |
| Agent | `tutor`、`sp`、`reviewer`、`evaluator`、`mentor` | 通过 prompt/config center 解析 | 管理端 Agent/提示词页 | **具备可封装基础**，但目前更像参数化 Agent，不是可观测的工作流编排 |

## 三、必须优先修复的问题

### P0：配置“保存了但无法证明生效”

`ai/app/services/model_registry.py:112-151` 只覆盖本次返回的激活模型；当管理端停用或删除某能力时，没有把对应 `settings` 恢复到 `.env` 基线。结果可能是管理端已经显示“无激活模型”，AI 进程仍继续使用旧的模型、密钥或地址。

同时，`ai/app/api/config.py:71-91` 的运行态只展示 `model_registry.latest` 和脱敏模型，不包含模型注册表最近成功刷新时间、配置版本、刷新失败原因和当前请求命中信息。

**修复要求：**

- 为每类模型维护启动基线，刷新时先全量 reset，再应用当前激活快照。
- 返回 `configVersion`、`source`、`lastRefreshAt`、`lastRefreshError`、`activeModelId`。
- 每次 AI 请求生成 `traceId`，在响应 metadata 和日志中记录 `capability/provider/model/configVersion/promptVersion/agentVersion/ragVersion`。
- 管理端增加“立即刷新”“发送验证请求”“查看最近请求”“回滚上一版本”，而不是只提示“约 30 秒热生效”。

### P0：降级结果必须与 AI 成功结果严格区分

- `ai/app/api/recommendation.py:58-68,81-90`：LLM 异常时仍返回 `R(data=result)`，外部很容易把规则建议当作 AI 建议。
- `ai/app/agents/mentor_agent.py:41-46`：模型异常/非法 JSON 返回空思维树，没有失败状态。
- `ai/app/api/vision.py:72-84,110-122`：视觉未配置或调用失败返回正常 `VisionAnalysisResult`，且 `citations=[]`。
- `backend/src/main/java/com/zhiyu/service/impl/StudentSessionServiceImpl.java:210-217`：评估归档失败只打日志，不进入待重试状态。

**统一响应契约建议：**

```json
{
  "status": "SUCCESS | DEGRADED | FAILED | PENDING",
  "source": "LLM | RULE | CACHE | NONE",
  "degraded": false,
  "traceId": "...",
  "configVersion": "...",
  "data": {},
  "citations": []
}
```

规则 fallback 只能用于“非评分、非归档、非临床结论”的辅助建议；不得写入正式成绩、学习掌握度或最终报告。

### P0：个性化与知识库证据不足

`ai/app/api/learning_path.py:35-39` 已明确说明没有学生历史数据，只生成“基于内科教学常见薄弱点”的通用路径。`LearningPathController` 虽然正确地从登录态取 studentId，但这只解决了越权，未解决个性化事实缺失。

要符合大赛“个性化、自适应、可追溯”，必须由业务中台提供学生事实快照：错题知识点、最近得分趋势、已学章节、任务完成率、推荐候选题/教材。AI 只负责基于这些事实规划，且输出每一步的依据和目标指标。

### P1：孤立能力和异步闭环

`AiPlatformClient.embedTextbook()` 在当前源码中没有发现业务调用者。教材上传后应产生 `INGESTING/INDEXED/FAILED` 任务记录、分片数、向量数、错误原因和重试按钮；否则不能把“有嵌入接口”作为 RAG 已完成证据。

`generateLearningPath()` 目前只有 mobile API/service，没有发现实际页面入口。要么补页面和状态持久化，要么从比赛材料中移除“已实现个性化学习路径”的表述。

## 四、硬编码与可维护性问题

已确认的高影响硬编码：

- `AiPlatformClient.java:271-272,302-303`：缺省学科写死为“内科”。应由课程/病例/用户当前上下文提供，默认值只能是可配置的演示基线。
- `AiPlatformClient.java:342`：课程时长写死 45 分钟。应使用教案模板或管理端学时配置。
- `front/src/admin/views/ai/AiStatus.vue:105`：同步间隔写死为 `'30'`，而后端是可配置的 `model_config_ttl_seconds`。
- 多处管理端提示词和确认框写死“约 30 秒内热生效”，与实际刷新失败/服务离线状态不一致。
- `ModelManageServiceImpl.java:187-190`：`EMBEDDING_MULTI` 明确“不支持一键连通测试”，导致多模态向量能力无法由管理端验证。
- `DataInitializer.java` 中存在演示账号和 `123456` 初始化逻辑；虽有生产开关说明，但必须在发布流水线增加生产阻断检查。

建议把默认学科、课程时长、超时、重试、刷新周期、候选数量、RAG top_k 全部归入“平台基线配置”，并在管理端显示“默认值、当前值、适用 Agent、风险等级、最后变更人”。

## 五、Agent 与多模态封装建议

### 建议形成的特定 Agent

1. **SP 标准病人 Agent**：病例状态机、追问策略、费用规则、安全边界、结束条件。输出必须包含可解释事件，而不是只有自然语言。
2. **OSCE 评估 Agent**：按评分量表逐项给证据、分数、置信度和缺失证据；最终成绩必须等待规则校验/教师确认。
3. **病例质检 Agent**：检查标准路径、隐藏疾病、检查结果、教学目标的一致性，阻止不完整病例发布。
4. **备课编排 Agent**：需求澄清 → 教材检索 → 教案生成 → 冲突合并 → 教师确认 → 发布。每一步记录版本和引用。
5. **个性化学习教练 Agent**：读取事实快照，输出目标、路径、推荐题和完成判定；不允许凭 studentId 猜测学习状态。
6. **教师复核 Agent**：只给出差异解释和追问建议，不直接改分。

### 多模态应落到可演示的完整场景

优先做“学生上传检验单/心电图截图 → 图像结构化识别 → RAG 检索教材解释 → 回到病例上下文追问 → 生成引用和安全提示”。现有视觉接口已能接收图片 URL、圈画框和备注，但必须补：图片来源白名单、图像任务状态、结构化字段、引用、失败可重试和结果人工确认。

## 六、按大赛要求的评分判断

| 评分项 | 当前判断 | 冲刺第一名的证据 |
|---|---|---|
| 垂直学科知识库 | 部分满足 | 展示真实教材来源、分片/向量统计、召回命中和引用 |
| 模型微调/优化 | 未见可验证闭环 | 至少提供领域术语/提示词评测集、模型 A/B 指标；不要只展示模型下拉框 |
| RAG | 已有工程能力，证据不足 | 召回前后对比、引用覆盖率、错误率、延迟和离线评测集 |
| 智能体编排 | 部分满足 | 展示 Agent 状态机、工具调用轨迹、失败重试和人工接管 |
| 多模态 | 有入口，部分满足 | 图像理解 + 检索引用 + 病例决策链路，不能只有 VLM 文本 |
| 可追溯/可解释 | 部分满足 | 每个答案关联 trace、模型/提示词/Agent/RAG 版本和证据片段 |
| 数据多元性 | 部分满足 | 教材、病例、检验图像、对话、作业和错题统一数据字典 |
| 复杂问题分析 | 有潜力 | 用一个跨病例、检查、教材和评分量表的完整 Demo 证明 |
| 个性化与自适应 | 当前不足 | 学生事实快照、学习状态更新、路径完成反馈闭环 |
| 真实用户与效果数据 | 未验证 | 至少准备教师/学生试用记录、任务完成率、满意度、准确率和延迟 |

## 七、冲刺顺序

### P0（先做，决定能否可信演示）

- 修复模型注册表全量 reset、刷新状态和版本化。
- 统一 `SUCCESS/DEGRADED/FAILED/PENDING` 响应，禁止 fallback 冒充成功。
- 建立 AI 请求审计事件：trace、模型、Agent、提示词、RAG、引用、耗时、错误。
- 把学生事实快照接入学习路径和推荐；把教材嵌入改成可观测异步任务。
- 让管理端支持“立即验证请求”和“实际生效证据”。

### P1（决定比赛展示质量）

- 把 SP 问诊、OSCE 评估、备课编排和多模态检验单串成一条可回放 Demo。
- 管理端改成业务语言：能力说明、输入/输出示例、风险提示、适用角色、当前版本和回滚。
- 增加 RAG/Agent 离线评测集与前后对比图，不用“模型已配置”替代效果证明。

### P2（稳定性和工程分）

- 修复 Spring 测试编译断裂，补端到端契约测试。
- 清理默认值、超时、重试和分页等散落硬编码。
- 增加任务幂等、失败重试、死信、告警和可恢复状态。
- 完成多模态向量模型管理端连通性测试。

## 八、当前验证结果

- AI 测试：`60 passed, 1 failed`。失败为 `test_ready_reports_optional_llm_without_failing`，测试依赖当前环境 LLM 配置，非 hermetic；另有 Pydantic `model_config_ttl_seconds` protected namespace warning。
- Spring Boot：`mvn test` 未进入测试执行，testCompile 失败，主要是 `TeacherCaseServiceImplTest`、`StudentAssignmentServiceImplTest`、`TeacherCaseControllerIntegrationTest` 与当前方法签名不一致。
- 未验证：真实 Provider、Milvus、Docker 编排、真实图片、压力、移动端真机、完整用户试用数据。因此不能在比赛材料中写“已生产验证”。

## 最终判断

你完全可以继续冲击第一名，但胜负点不是再堆十个接口，而是把现有能力变成**可解释、可回放、可验证、可回滚的真实闭环**。最值得押注的比赛主线是：**教材 RAG + SP 多模态问诊 + OSCE 可解释评估 + 个性化学习教练 + 管理端运行态证据**。这五项串起来，才会从“AI 功能很多”升级为“学科垂类 AI 中台真正驱动教学业务”。
