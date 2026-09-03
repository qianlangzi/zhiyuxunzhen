# 数据扩充与 RAG 链路优化说明文档

> 适用场景：比赛/教学/评委评审（学术性质）  
> 版本：v1.0  
> 日期：2026-09-02

---

## 一、扩充成果总览

本次工作围绕"垂类医学软件的数据底座"目标，对病例库、题库、向量知识库三大核心模块进行了系统性扩充与质量治理。

| 模块 | 扩充前 | 扩充后 | 增幅 | 数据来源 |
|------|--------|--------|------|----------|
| **病例库** | 81 例 | **6,081 例** | +75x | Chinese-medical-dialogue-data（医患对话→标准化病例） |
| **题库** | ~1 万题 | **56,388 题** | +5.6x | CMB-train（临床综合选择题） |
| **向量知识库** | ~2,000 条 | **19,936 条** | +10x | 教材/问答库 + OpenCMKG 中文医学知识图谱 |

> 注：向量库 19,936 条 = 教材/问答原有 ~2,000 条 + OpenCMKG 8,566 条 + 医患问答库 1,811 条 + 其他。

---

## 二、各模块扩充详情

### 2.1 病例库扩充

**数据来源**：Chinese-medical-dialogue-data（开源中文医患对话数据集）

**处理链路**：
1. **原始对话**（title + ask + answer）
2. **结构化转换** → `sp_case_config` 入门级咨询型病例
   - 主诉、现病史来自患者 ask
   - 医生建议来自医生 answer
   - 自动提取评分要点、诊断方向
   - 人格标签：话多/普通患者（按 ask 长度自动判定）
3. **去重**：按 title 去重，避免同一对话多次入库
4. **写入**：MySQL `sp_case_config` 表

**质量保障**：
- 对话数据经过清洗过滤（剔除过短/空值/异常编码）
- 入库前与现有病例做 title 级去重
- 生成 `case_summary`、`score_points`、`difficulty_level` 等结构化字段

**脚本**：`datasets/import_dialogue_cases.py`

---

### 2.2 题库扩充

**数据来源**：CMB（Clinical Medicine Benchmark）- train 集

**处理链路**：
1. 从 CMB-train 抽取 50,000 题（原仅 10,000 题）
2. 清洗：过滤无答案项、异常选项、重复题面
3. 映射到 `sp_question_config` 标准字段
4. 写入 MySQL

**成果**：新增 46,198 题，总量达 56,388 题。

**脚本**：`datasets/import_question.py`

---

### 2.3 向量知识库扩充（重点）

#### 2.3.1 数据来源

**OpenCMKG**（开源中文医学知识图谱）
- 聚合来源：QAKG + OwnThink + CHIP2021
- 规模：35.5 万三元组，14,726 疾病、19,411 症状、4,289 药物等
- **授权性质**：仅限学术研究，不得商用
- **合规说明**：本项目为比赛/教学用途，属学术性质，与授权边界一致

#### 2.3.2 清洗与规范化

仅采纳**疾病维度**的高价值诊疗关系：

| 关系类型 | 转化后章节 | 示例 |
|----------|-----------|------|
| disease_has_symptom | 常见症状 | 头痛、头晕 |
| disease_need_check | 可能需要检查 | 血常规、CT |
| disease_recommand_drug | 推荐药物 | 二甲双胍、卡托普利 |
| disease_common_drug | 常用药物 | 阿司匹林 |
| disease_need_treatment | 常用治疗方式 | 饮食控制、手术 |
| disease_belong_department | 所属科室 | 心内科、内分泌科 |
| disease_acompany_disease | 可能并发 | 糖尿病肾病 |
| disease_recommand_food | 推荐食物 | 蔬菜、粗粮 |
| disease_noteat_food | 忌口食物 | 辛辣、高糖 |
| disease_eat_food | 可吃食物 | 鸡肉、鸡蛋 |

**清洗规则（垂类硬标准）**：
1. 疾病名必须是规范中文（2-16 字，无数字/英文/标点）
2. 按逗号/顿号拆分多值实体，逐条校验
3. 症状 ≤20 字、药物 ≤30 字、检查 ≤60 字、治疗 ≤120 字
4. 半角引号/残次占位词（如"测试""nan"）直接剔除
5. 值含数字/英文/异常符号的一律过滤

**Chunk 生成**：按疾病聚合多维度信息，生成结构化文本：

```
【高血压】
所属科室：心内科
常见症状：头痛、头晕、心悸、胸闷
推荐药物：卡托普利片、硝苯地平缓释片、厄贝沙坦片
可能需要检查：血常规、心电图、肾功能
常用治疗方式：饮食控制、运动疗法、药物治疗
```

超长疾病（症状极多）按症状分批切块，单条 ≤3600 字节（UTF-8 安全截断）。

#### 2.3.3 嵌入与入库

- **嵌入模型**：DashScope `qwen3-vl-embedding`（1024 维）
- **向量库**：Milvus `zhiyu_textbook` 集合
- **索引**：AUTOINDEX (COSINE) + subject/chapter INVERTED 索引
- **幂等写入**：按文本 MD5 生成 id，重复运行自动跳过，零重复污染
- **嵌入缓存**：本地 JSON 缓存，命中则复用，避免重复调 API
- **并发**：6 线程并发嵌入，批量 upsert（50 条/批）

**成果**：8,566 疾病 → 8,566 条 chunk，嵌入失败 0，全部入库。

**脚本**：`datasets/import_opencmkg_knowledge.py`

---

## 三、RAG 检索链路优化

### 3.1 链路架构

```
用户查询
    ↓
[查询改写]（可选）口语 → 医学术语 + 指代消解
    ↓
[Dense 检索] Milvus 向量搜索 top-20（COSINE）
    ↓ 并发 ↓
[BM25 稀疏检索] 基于 jieba 分词的全文倒排索引 top-20
    ↓
[RRF 融合] Reciprocal Rank Fusion (k=60) 合并 Dense + Sparse
    ↓
[LLM 重排]（可选，高精度场景）对 Top-20 精排，取 Top-5
    ↓
[LLM 生成] 基于检索资料生成 grounded 回答 + 出处标注
```

### 3.2 检索策略对比

| 策略 | 延迟 | 质量 | 适用场景 |
|------|------|------|----------|
| **dense** | ~2s | 基线 | 快速查询、对延迟敏感 |
| **hybrid**（默认） | ~4s | 优 | 生产主路径，BM25+RRF 互补 |
| **rerank** | ~6-8s | 最优 | 高精度生成、评委演示、复杂问诊 |

> 延迟数据基于 2 万条向量集合、通点模型环境实测。

### 3.3 修复的关键 Bug

#### Bug 1：BM25 分页窗口超限 → hybrid 静默降级

**现象**：集合超过 1.6 万条后，`hybrid` 策略实际退化为纯 `dense`，RRF 融合失效。

**根因**：BM25 建索引用 `limit=1000, offset+=1000` 分页拉取全量，撞上 Milvus `offset+limit ≤ 16384` 的查询窗口上限，抛异常后返回 `None`，调用方降级为 dense。

**修复**：改用 `query_iterator` 滚动分页（游标遍历，无窗口上限），老版本 pymilvus 保留 offset 分页兜底。

**复验**：BM25 正常构建 `docs=19936`，`hybrid_fallback_dense` 不再触发。

**文件**：`app/services/hybrid_retrieval.py`

#### Bug 2：dense 与 BM25 串行执行 → 冷启动长尾

**现象**：冷启动时 BM25 首次构建需遍历 2 万条，串行阻塞在 dense 之后，总延迟偏高。

**修复**：`_search_once` 中 dense 检索与 BM25 构建/稀疏检索改为 `asyncio.gather` 并发执行。

**文件**：`app/services/rag_service.py`

---

## 四、端到端验证结果

### 4.1 检索抽验（向量层）

| 查询 | Top-1 命中 | 相关性 |
|------|-----------|--------|
| 高血压该挂什么科，有哪些症状，平时吃什么药 | 高血压 / 心内科 | 0.744 |
| 糖尿病患者常见症状和一般处理方式 | 糖尿病合并低血糖 | 0.859 |
| 感冒一般需要做哪些检查 | 人禽流行性感冒 | 0.784 |

### 4.2 用例级 RAG 压测（检索 → 生成）

**hybrid vs rerank 对比**：

| 用例 | hybrid 来源分布 | rerank 来源分布 | 质量差异 |
|------|----------------|----------------|----------|
| 高血压 | 问答库 4 + 病理 1 | **图谱 4** + 问答 1 | rerank 给出科室+7类降压药，hybrid 答"资料不足" |
| 糖尿病 | 问答库 3 + 图谱 2 | 图谱 3 + 问答 2 | rerank 多出胰岛素、低血糖急救 |
| 感冒 | 图谱 3 + 教材 1 + 问答 1 | **图谱 4** + 问答 1 | rerank 滤除无关条目，更聚焦 |

**结论**：
- `hybrid` 已满足日常检索，速度与质量均衡
- `rerank` 在高精度场景显著提升回答深度与结构化程度
- LLM 生成严格 grounded，逐条标注出处编号（如〔1〕〔3〕）

---

## 五、数据来源与可溯源性

所有向量知识均通过 `book_name` 字段标记来源，支持独立筛选与追溯：

| book_name | 类型 | 规模 | 说明 |
|-----------|------|------|------|
| 内科学（第10版） | 教材 | ~千条 | 权威教科书 |
| 医患问答知识库(咨询参考) | 问答 | ~2,000 条 | 真实医患对话清洗 |
| 中文医学知识图谱(OpenCMKG) | 图谱 | 8,566 条 | 结构化疾病知识 |

评委/用户可在回答中直接看到每条知识的来源书籍与章节，确保透明可溯。

---

## 六、生产环境部署建议

### 6.1 配置策略

```python
# 默认路径（快）
settings.rag_strategy = "hybrid"
settings.rag_top_k = 5
settings.iterative_search_enabled = True  # 自适应二次检索，首轮回分低时自动补查

# 高精度路径（慢但准）
# 在生成回答、评委演示等场景显式传入 strategy="rerank"
```

### 6.2 环境依赖

| 组件 | 版本要求 | 说明 |
|------|---------|------|
| Milvus | 2.3+ | 向量存储，支持 AUTOINDEX + INVERTED |
| MySQL | 8.0+ | 病例/题库/结构化数据 |
| DashScope | - | 嵌入模型 qwen3-vl-embedding |
| LLM | deepseek-chat / 兼容 OpenAI 协议 | 查询改写 + 重排 + 生成 |
| Python | 3.11+ | pymilvus, jieba, openai |

### 6.3 运行脚本清单

| 脚本 | 用途 | 运行频率 |
|------|------|----------|
| `datasets/import_question.py` | 题库扩充 | 一次性/定期增量 |
| `datasets/import_dialogue_cases.py` | 病例库扩充 | 一次性/定期增量 |
| `datasets/import_opencmkg_knowledge.py` | 向量库扩充 | 一次性（幂等可重跑） |
| `datasets/verify_opencmkg_retrieval.py` | 检索抽验 | 验证时 |
| `ai/e2e_rag_check.py` | 端到端压测 | 验证时 |

---

## 七、合规与授权说明

### 7.1 OpenCMKG 使用合规性

- **来源**：开源中文医学知识图谱（GitHub: OpenCMKG）
- **授权声明**："仅用于学术研究，不得用于商用"
- **本项目性质**：比赛/教学/评委评审，属学术性质
- **结论**：在学术场景下使用符合授权边界

### 7.2 其他数据来源

- CMB（Clinical Medicine Benchmark）：公开学术基准数据集
- Chinese-medical-dialogue-data：开源医患对话数据集
- 内科学教材：已有授权或公开引用

---

## 八、后续可扩展方向

1. **向量库增量更新**：新数据源（如权威指南、临床共识）可按同样清洗→嵌入→幂等入库的流程扩展
2. **多模态扩展**：当前嵌入模型支持图文混合，未来可接入医学影像的向量检索
3. **领域自适应重排**：针对特定科室（心内科/内分泌科）训练轻量级重排模型，替代通用 LLM 重排以降低成本
4. **实时索引更新**：当前 BM25 为启动时构建，大规模高频更新时可改为增量更新策略

---

## 九、关键文件索引

| 文件 | 说明 |
|------|------|
| `datasets/import_opencmkg_knowledge.py` | OpenCMKG 清洗→嵌入→入库主脚本 |
| `datasets/import_dialogue_cases.py` | 病例库扩充脚本 |
| `datasets/import_question.py` | 题库扩充脚本 |
| `app/services/rag_service.py` | RAG 检索服务（hybrid/rerank/dense） |
| `app/services/hybrid_retrieval.py` | BM25 构建、RRF 融合、LLM 重排 |
| `app/services/milvus_service.py` | Milvus 连接、索引、搜索 |
| `app/services/query_rewriting.py` | 查询改写（口语→术语） |
| `ai/e2e_rag_check.py` | 端到端验证与压测脚本 |

---

> 文档维护：后续数据扩充或链路调整时，建议同步更新本说明。
