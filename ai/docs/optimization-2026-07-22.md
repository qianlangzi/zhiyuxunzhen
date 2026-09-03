# AI 中台优化开发文档

> 日期：2026-07-22
> 范围：`e:/zhiyu/ai/` AI 中台服务
> 目标：修复安全漏洞、消除阻塞问题、引入领域策略层、替换 hack 解析

---

## 一、本次改了什么（总览）

| # | 类型 | 文件 | 改了什么 |
|---|---|---|---|
| 1 | 新建 | `app/domain/policies/safety_policy.py` | 集中安全策略（输入阻断 + 输出泄露检测） |
| 2 | 新建 | `app/domain/policies/output_policy.py` | SP 回复校验（防泄露/超长/医学术语） |
| 3 | 新建 | `app/services/structured_output.py` | 严格 JSON 解析服务（替换 hack） |
| 4 | 修改 | `app/services/backend_client.py` | 复用共享 HTTP client，不再每次创建 |
| 5 | 修改 | `app/core/lifecycle.py` | 启动时注入共享 client 到 backend_client |
| 6 | 修改 | `app/services/milvus_service.py` | 同步 pymilvus 调用放入线程池 |
| 7 | 修改 | `app/services/rag_service.py` | 删除零向量降级，改为抛错 |
| 8 | 修改 | `app/api/embed.py` | SSRF 修复 + chunk_id 稳定化 |
| 9 | 修改 | `app/workflows/chat_workflow.py` | 使用新 safety_policy + output_policy |
| 10 | 修改 | `app/services/llm_client.py` | 使用 structured_output 替换 _safe_json_load |

---

## 二、新建文件详解

### 2.1 `app/domain/policies/safety_policy.py`

**问题**：之前安全检查散在 `chat_workflow.py` 的 `_SAFETY_KEYWORDS` 元组里，只有 7 个关键词，没有输出检查，无法检测模型是否泄露了系统提示词或隐藏疾病。

**改动**：把安全策略抽到独立的领域层，分输入检查和输出检查。

```python
from app.domain.policies.safety_policy import safety_policy

# 检查学生输入
decision = safety_policy.check_input("我想自杀")
# -> SafetyDecision(action=BLOCK, reason="检测到高危敏感内容")

# 检查模型输出（传入隐藏疾病名，检测是否泄露）
decision = safety_policy.check_output("你的隐藏疾病是肺炎", hidden_disease="肺炎")
# -> SafetyDecision(action=BLOCK, reason="模型输出疑似直接泄露隐藏诊断")
```

三种动作：
- `ALLOW`：放行
- `DEFLECT`：转教学免责声明（如学生问处方/剂量）
- `BLOCK`：直接拦截

### 2.2 `app/domain/policies/output_policy.py`

**问题**：SP Agent 生成的回复直接发给学生，没有校验是否泄露隐藏疾病、是否超长、是否包含医学术语。

**改动**：在 SP 回复发给学生前做校验。

```python
from app.domain.policies.output_policy import output_policy

result = output_policy.validate_sp_reply(reply, hidden_disease="肺炎")
if not result.passed:
    if result.action == "BLOCK":
        # 用安全文案替代，不保存原始回复
        reply = "抱歉，我无法回答这个问题。"
    # REGENERATE 记录日志
```

校验项：
1. 非空检查
2. 长度检查（上限 500 字）
3. 安全策略复用（泄露检测）
4. 医学术语检查（患者不该说"鉴别诊断"等词）

### 2.3 `app/services/structured_output.py`

**问题**：`llm_client.py` 的 `_safe_json_load()` 用"找首个 `{` 和最后 `}`"的 hack 解析 JSON，解析失败返回 `{"_raw": text}` 隐藏错误。

**改动**：新建 `StructuredOutputService`，按优先级尝试三种提取方式，解析失败抛 `OutputSchemaInvalidError`。

```python
from app.services.structured_output import structured_output

# 解析为字典（带必需字段检查）
data = await structured_output.parse_to_dict(
    raw_text=model_output,
    required_keys=("score", "dimensions"),
    trace_id=trace_id,
)

# 解析为 Pydantic 模型（严格校验）
result = await structured_output.parse_and_validate(
    raw_text=model_output,
    model_class=ReviewResult,
    trace_id=trace_id,
)
```

提取优先级：
1. 直接是 JSON（`{"key": "value"}`）
2. 从 ` ```json ... ``` ` 代码块提取
3. 找首个 `{` 到最后 `}`，验证 JSON 合法性

---

## 三、修改文件详解

### 3.1 `app/services/backend_client.py` — 复用 HTTP client

**问题**：每次回调都 `httpx.AsyncClient()` 临时创建连接池，浪费资源。

**改动**：
- 新增 `set_shared_client()` 方法，由 lifecycle 在启动时注入共享 client
- 新增 `_close_if_temporary()` 方法：共享 client 不关闭，临时 client 用完关闭
- `_post()` / `session_context()` / `report_context()` 不再用 `async with`，改用 `try/finally`

### 3.2 `app/core/lifecycle.py` — 注入共享 client

**改动**：在 `startup()` 中添加一行：
```python
backend_client.set_shared_client(self.http_client)
```

### 3.3 `app/services/milvus_service.py` — 线程池

**问题**：pymilvus 是同步库，直接在 async 路由中调用会阻塞 FastAPI 事件循环。

**改动**：
- 新增 `_connect_sync()` 同步方法（连接 + 创建 collection）
- `_ensure_connected()` 用 `await asyncio.to_thread(self._connect_sync)` 调用
- `upsert()` / `search()` / `count()` 的 pymilvus 调用都用 `await asyncio.to_thread(...)` 包装

### 3.4 `app/services/rag_service.py` — 不返回零向量

**问题**：Embedding 不可用时返回零向量，让 Milvus 检索"继续执行但结果为空"，属于伪造结果。

**改动**：
- 删除 `_zero_vector()` 函数和 `_ZERO_VEC` 全局变量
- `embed()` / `embed_batch()` 不可用时直接抛 `RetrievalUnavailableError`
- `search()` 会传递异常，由调用方（chat_workflow）捕获并降级

### 3.5 `app/api/embed.py` — SSRF 修复 + chunk_id 稳定化

**问题 1**：接受任意 `fileUrl` 下载 PDF，存在 SSRF 风险（可访问内网/localhost）。
**改动 1**：新增 `_is_safe_url()` 函数，校验协议（仅 http/https）和 IP（禁止内网/loopback/link-local）。

**问题 2**：chunk_id 用 `f"tb{textbookId}_c{idx}"`，重新入库会覆盖旧数据。
**改动 2**：chunk_id 改为 `f"tb{textbookId}_{md5_hash[:12]}"`，基于内容哈希，重新入库能正确去重。

### 3.6 `app/workflows/chat_workflow.py` — 使用新 policy

**改动**：
- 删除 `_SAFETY_KEYWORDS` 元组和 `safety_blocked()` 函数
- 导入 `safety_policy` 和 `output_policy`
- 安全检查改用 `safety_policy.check_input()`，支持 BLOCK + DEFLECT 两种动作
- SP 回复生成后新增 `output_policy.validate_sp_reply()` 校验
- BLOCK 时用安全文案替代原始回复，不保存到后端

### 3.7 `app/services/llm_client.py` — 使用 structured_output

**问题**：`_safe_json_load()` 用 hack 方式解析 JSON，失败返回 `{"_raw": text}` 隐藏错误。

**改动**：
- 删除 `import json` 和 `_safe_json_load()` 函数
- 导入 `from app.services.structured_output import structured_output`
- `chat_json()` 改用 `await structured_output.parse_to_dict(text, trace_id=trace_id)`
- 解析失败抛 `OutputSchemaInvalidError`，调用方需要 try/except

---

## 四、行为变化说明（重要）

### 4.1 `chat_json()` 不再返回 `{"_raw": text}`

| 场景 | 旧行为 | 新行为 |
|---|---|---|
| JSON 解析成功 | 返回 dict | 返回 dict（不变） |
| JSON 解析失败 | 返回 `{"_raw": text}` | 抛 `OutputSchemaInvalidError` |
| LLM 降级模式 | 返回 `{"_raw": "降级文案"}` | 抛 `OutputSchemaInvalidError` |

**影响**：调用方（`mentor_agent` / `evaluator_agent` / `reviewer_agent`）已有 try/except 处理，行为正确。

### 4.2 RAG 不可用时不返回空结果

| 场景 | 旧行为 | 新行为 |
|---|---|---|
| Embedding 未配置 | 返回零向量，Milvus 返回空结果 | 抛 `RetrievalUnavailableError` |
| Embedding 调用失败 | 返回零向量 | 抛 `RetrievalUnavailableError` |

**影响**：`chat_workflow.py` 已有 `except RetrievalUnavailableError` 捕获，会发送降级 SSE 事件。

### 4.3 安全检查更严格

| 场景 | 旧行为 | 新行为 |
|---|---|---|
| 学生问"处方" | 不拦截 | DEFLECT（转教学免责声明） |
| SP 回复泄露隐藏疾病 | 不检查 | BLOCK（用安全文案替代） |
| SP 回复包含医学术语 | 不检查 | REGENERATE（记录日志） |

---

## 五、验证结果

```
policies + structured_output OK
services OK
workflow + api OK
FastAPI app OK, routes: 23
```

所有模块导入正常，FastAPI 应用初始化正常，23 个路由全部注册。

---

## 六、后续待办（按优先级）

### P0 — 已完成
- [x] SSRF 修复（embed.py URL 安全校验）
- [x] Embedding 零向量降级修复
- [x] backend_client HTTP client 复用
- [x] Milvus 同步调用线程池
- [x] JSON 解析 hack 替换
- [x] chunk_id 稳定化
- [x] 安全策略集中化
- [x] SP 输出校验

### P1 — 下一步建议
- [ ] 接入真实 LLM API（在 `.env` 配置 `LLM_BASE_URL` / `LLM_API_KEY`）
- [ ] 接入真实 Embedding API（配置 `EMBEDDING_BASE_URL` / `EMBEDDING_API_KEY`）
- [ ] 接入 Milvus（配置 `MILVUS_HOST` / `MILVUS_PORT`）
- [ ] 接入 Redis（配置 `REDIS_HOST`，启用任务队列）
- [ ] 生产环境配置校验（`ENV=prod` 时强制修改 dev-only 密钥）
- [ ] Prompt 版本化（拆分到 `prompts/v1/` 目录）
- [ ] 可观测性（接 Prometheus + OpenTelemetry）

### P2 — 长期演进
- [ ] 引入 LiteLLM 统一模型网关
- [ ] 引入 Langfuse 记录 token/费用
- [ ] RAG 重排（bge-reranker）
- [ ] PDF 按章节感知切块
- [ ] Token budget 限制
- [ ] SSE 断线重连幂等键
- [ ] DeepEval 评测集
