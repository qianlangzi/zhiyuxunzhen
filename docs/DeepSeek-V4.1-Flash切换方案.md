# DeepSeek V4.1 Flash 切换方案（含多模态评估）

日期：2026-09-10　｜　状态：**P0 + P1 已实施，本地全链路验证通过**　｜　待办：线上部署（见第 7 节）

---

## 0. 一句话结论

| 你的疑问 | 答案 |
|---|---|
| 怎么切换大模型？ | 管理端「模型管理」设激活即可，**30 秒热生效**，不用重启容器 |
| 我已经在用什么？ | **已经就是 V4.1 Flash**。旧名 `deepseek-v4-flash` 被官方路由到 V4.1 Flash，实测响应 `model` 字段回的是 `deepseek-flash` |
| 多模态要链路大升级吗？ | **不需要。零结构改动。** VISION 是独立能力槽位，请求体格式与官方文档逐字一致，改一行 DB 即可 |
| 管理端能热切换吗？ | **能，已实现**（`POST /api/v1/admin/models/{id}/active`），30s 内自动生效 |
| 真正要改几处？ | **必做 4 处（其中只有 1 处代码，+3 行）** |

---

## 1. 本地实测结果（全部已跑通）

探针脚本：`_probe_deepseek_flash.py`、`_probe_risk.py`（根目录，可复跑）
运行方式：`docker cp` 进 `zhiyu-ai` 容器 → `python /tmp/xxx.py`
测试图片：`素材/微信图片_20260828205900_481_5.jpg`

| # | 测试项 | 请求模型名 | 结果 | 关键数据 |
|---|---|---|---|---|
| 1 | JSON 结构化 + 关思考链 | `deepseek-flash` | ✅ | 1335ms / 51 tokens / 正文合法 JSON |
| 2 | 旧名兼容验证 | `deepseek-v4-flash` | ✅ | 响应 `model=deepseek-flash` → **证实已被官方路由** |
| 3 | 思维链默认开启 | `deepseek-flash` | ✅ | reasoning 1434 字 / 431 tokens（**8.4×**）/ 2243ms |
| 4 | **多模态读图** | `deepseek-flash` | ✅ | 1064ms / 730 tokens，正确描述图片内容 |
| 5 | 读图 `detail=low` | `deepseek-flash` | ✅ | 888ms / 280 tokens（**省 62%**） |
| 6 | 思考开启 + `temperature=0.7` | `deepseek-flash` | ✅ | 不报错，但**被静默忽略** |
| 7 | 思考 + tools + 回传 `reasoning_content` | `deepseek-flash` | ✅ | `finish=stop`，正常收敛给出答案 |
| 8 | 思考 + tools + **丢弃** `reasoning_content` | `deepseek-flash` | ⚠️ | 不报 400，但模型**重复发起工具调用**，收不敛 |

### 关键发现

1. **旧模型名不会断线**。官方明确「`deepseek-v4-flash` 与 `deepseek-v4-flash-vision-exp` 仍被接受，但对应模型已下线，请求由 DeepSeek-V4.1-Flash 提供服务，按 Flash 价格计费」。实测响应 `model` 字段返回 `deepseek-flash`，坐实了这一点。**换句话说：改名是「账面对齐」，不是「能力升级」。**

2. **`deepseek-v4-pro` 将在 2026-09-14 12:00（北京时间）进入有序下线**，之后请求全部路由到 V4.1 Flash。我们项目没用 pro，不受影响。

3. **多模态格式完全一致**。官方 vision 文档给的请求体是：
   ```json
   {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,..." }}
   ```
   而 `ai/app/api/vision.py` 第 97-100 行发的就是：
   ```python
   user_content = [
       {"type": "text", "text": f"{bbox_desc}\n学生备注：{req.student_note or '无'}"},
       {"type": "image_url", "image_url": {"url": image_url}},
   ]
   ```
   **逐字一致，零代码改动。**

4. ⚠️ **`resolve_tools` 有现存隐患**。`LlmClient.resolve_tools`（llm_client.py:352-394）回填 assistant 消息时只放了 `content` + `tool_calls`，**丢掉了 `reasoning_content`**。官方文档：「带 `tools` 参数时，所有后续请求必须完整回传 `reasoning_content`，否则返回 400」。实测未报 400，但模型会重复发起同一工具调用（不收敛）。属真实缺陷，修法 +3 行。

5. **测试插曲（值得记一笔）**：第一次读图报 400「不支持的图片格式」，排查发现 `logs/e2e_casemarket.png` 文件头是 `EFBBBF EFBFBD` + `PNG` —— 文件被 BOM 污染了，不是合法 PNG。换成真 JPEG 立刻通过。**不是代码问题，但说明仓库里部分 png 资源是坏的。**

### 成本参考（官方价，per 1M tokens）

| | 缓存命中 输入 | 缓存未命中 输入 | 输出 |
|---|---|---|---|
| 低谷时段 | $0.003 | $0.15 | $0.6 |
| 高峰时段 | $0.006 | $0.3 | $1.2 |

上下文 1M，最大输出 384K，并发上限 2500。图片按尺寸折算，**单图上限 1024 tokens**。

---

## 2. 当前配置全景（本地实查）

### DB `ai_model` 表

| id | capability | name | model | base_url | is_active |
|---|---|---|---|---|---|
| 1 | LLM | DeepSeek V4 Flash | `deepseek-v4-flash` | `https://api.deepseek.com/v1` | ✅ |
| 2 | VISION | qwen3-omni-flash 视觉 | `qwen3-omni-flash` | 阿里云 MaaS `/compatible-mode/v1` | ✅ |
| 3 | EMBEDDING | bge-m3 向量 | `BAAI/bge-m3` | `https://api.siliconflow.cn/v1` | ✅ |
| 4 | EMBEDDING_MULTI | qwen3-vl-embedding | `qwen3-vl-embedding` | 阿里云 MaaS `/api/v1` | ✅ |

### env 兜底层

| 位置 | LLM_MODEL | 是否生效 |
|---|---|---|
| 根 `.env` | `deepseek-v4-flash` | 被 DB 覆盖 |
| `ai/.env` | `deepseek-v4-flash` | 被 DB 覆盖 |
| 容器 `zhiyu-ai` | `deepseek-chat` | 被 DB 覆盖 |

**优先级：DB 激活行 > env。** 所以「我改了 .env 怎么没生效」的答案是：**改 .env 无效，必须改 DB 或走管理端。**

---

## 3. 怎么切换大模型 —— 3 条路径

### 路 1（推荐）管理端设激活 · 热切换 · 零重启

```
管理端 → 模型管理 → 选一条 → 「设激活」
  ↓ POST /api/v1/admin/models/{id}/active
ai_model 表 is_active 翻转（同能力互斥）
  ↓ AI 中台 ModelRegistry 每 30s 轮询 GET /api/internal/model/active
settings.* 被覆写 → llm_client.rebuild() + rag_service.rebuild()
  ↓
下次请求即用新模型（TTL = model_config_ttl_seconds = 30s）
```

### 路 2（推荐并行）新增一条配置做 AB 互切

管理端「新增模型」→ capability 选 `LLM` → 填 base_url / apiKey / model → 先点「连通性测试」→ 再「设激活」。
好处：旧行留着当回退目标，一键切回；出问题不用改代码不用重建。

### 路 3（兜底）改基础设施 env

改 `.env` 里 `LLM_MODEL` → 重建容器。**仅在某能力在 DB 里一条配置都没有时才是唯一来源。** 本项目的 4 个能力都已配齐，所以这条路目前无效。

---

## 4. 多模态是否需要大升级？—— 不需要，理由如下

**架构本来就解耦。** 模型配置是按「能力维度」切成 4 个独立槽位的：

```
LLM              → 对话 / 评审 / 报告 / 结构化 JSON
VISION           → 影像 / 检验单读图
EMBEDDING        → 文本向量
EMBEDDING_MULTI  → 多模态向量
```

多模态 = `VISION` 槽位，**不是 LLM 的升级**。每个槽位各自持有 base_url / api_key / model，可指向不同供应商。

**所以把 VISION 指向 DeepSeek，等价于改一行 DB：**

```
base_url: https://ws-z7vi5mam4d8415c8.cn-beijing.maas.aliyuncs.com/compatible-mode/v1
          → https://api.deepseek.com
model:    qwen3-omni-flash  → deepseek-flash
```

**不需要改的**：LangGraph 工作流、移动端、后端 Java、数据库结构、提示词模板（`vision_agent_prompt` 通用）。

### 非代码注意点（3 条）

| 项 | 现状 | 影响 |
|---|---|---|
| `VISION_ALLOWED_HOSTS` | `[]`（空），prod 才校验 | 走 DeepSeek 外部 URL 时，prod 需补 MinIO 域名白名单，否则 403。dev 不受限 |
| 图片位置限制 | 官方：图片只能放 `user` 消息，放 `system`/`assistant` 返 400 | 我们的代码本来就只放 user，**无影响** |
| base64 备选 | 官方支持 `data:image/...;base64,` 内联 | 可绕开白名单，但需 AI 服务自己取图（涉及 SSRF 权衡）。**暂不做** |

---

## 5. 改动计划

### P0 必做（4 处，只有 1 处是代码）

| 编号 | 改动 | 文件 | 规模 | 状态 |
|---|---|---|---|---|
| **A** | 模型名 `deepseek-v4-flash` → `deepseek-flash` | 根 `.env`、`ai/.env`、`docker-compose.yml` | 改字符串 | ✅ 已改（服务器 `.env` 待你改） |
| **B** | `resolve_tools` 回填 `reasoning_content` | `ai/app/services/llm_client.py` | **+5 行** | ✅ 已改 |
| **C** | 新增一条 `deepseek-flash` 配置行，保留旧行做回退 | 管理端「新增模型」（**非 SQL**） | 0 代码 | ⬜ **你做**（管理端操作） |
| **D** | 幂等迁移更新 model 字段 | `V51__llm_model_rename_deepseek_flash.sql` | 1 个 SQL | ✅ 已建（Flyway 上线自动执行） |

### P1 建议做（稳定性）

> **实现方式说明（低耦合 / 高内聚）**：E 没有去改 12 个调用点，而是把「结构化输出默认关闭思维链」
> 收敛到 `chat_json` 这一个入口的默认值上。语义上「要 JSON」本身就隐含「要确定性、不要推理过程」，
> 放在入口层最内聚；12 个调用点零改动，最不耦合；将来某个场景确实需要推理后出 JSON，
> 显式传 `disable_thinking=False` 即可覆盖。

| 编号 | 改动 | 依据 | 状态 |
|---|---|---|---|
| **E** | `chat_json` 默认 `disable_thinking=True`（**一处覆盖 12 个调用点**）；`ModelGateway` 同步默认值 | V4.1-Flash 思考默认 `effort=high`；思考链与正文共享 `max_tokens`，实测 8.4× token 消耗，是历史 `llm_chat_truncated` 主因 | ✅ 已改（`llm_client.py` + `model_gateway.py`） |
| **F** | 日志补 `thinking` 字段 + 注释说明 | 官方：思考模式**不支持** temperature（传了静默忽略）。E 落地后结构化场景温度已生效；流式对话仍保留思考（质量优先），此时温度无效 —— 靠 `thinking=true` 日志可秒定位 | ✅ 已改（`llm_chat_ok` / `llm_chat_truncated`） |
| **G** | 探针脚本固化为集成用例 | 避免每次换模型都重写一次性脚本 | ✅ 已建 `ai/tests/integration/test_llm_capabilities.py` |

#### 集成用例运行方式（默认跳过，需真实 API）

```bash
# 1. 同步测试代码进容器（/app/app 是 bind mount，tests 不在挂载范围内）
docker cp ai/tests/.  zhiyu-ai:/app/tests/
docker cp ai/pyproject.toml zhiyu-ai:/app/pyproject.toml

# 2. 运行（RUN_LLM_INTEGRATION=1 才真正执行，避免误烧 token）
docker exec -e RUN_LLM_INTEGRATION=1 -e LLM_MODEL=deepseek-flash \
  -e no_proxy='*' -e NO_PROXY='*' -w /app \
  zhiyu-ai python -m pytest tests/integration -q
```

覆盖 4 项：结构化输出未被思维链截断 / 旧模型名被路由到 Flash / 多模态读图 / 工具调用收敛。
测试图片用代码生成纯色 PNG，**不依赖仓库图片资源**（仓库里部分 png 被 BOM 污染会被第三方 400 拒收）。

#### 离线测试

```bash
docker exec -e no_proxy='*' -e NO_PROXY='*' -w /app \
  zhiyu-ai python -m pytest tests/unit tests/contract tests/security -q
```

顺带修了 `tests/conftest.py` 里 `fake_chat_json` 的桩签名（缺 `temperature/max_tokens/disable_thinking`，
与 `ModelGateway` 转发参数不一致 → 6 个契约测试误报 503，属**既存问题**，与本次改动无关）。
修复后 **86 passed, 4 skipped**。

### P2 明确不做（防过度设计）

- ❌ 不把 LLM / VISION 合并成「统一多模态入口」—— 两者失败模式、降级策略、白名单规则不同，合并会牺牲可用性
- ❌ 不引入新的模型抽象层 / 路由策略框架 —— 现有 `ModelRegistry` + capability 槽位已够用
- ❌ 不改移动端、不改工作流、不改数据库结构
- ❌ 不把 `reasoning_effort` 提到管理端配置项（收益低）

---

## 6. 已完成改动清单（2026-09-10 晚）

| 文件 | 改动 |
|---|---|
| `ai/app/services/llm_client.py` | ① `resolve_tools` 回填 `reasoning_content`（修工具调用不收敛）<br>② `chat_json` 默认 `disable_thinking=True`<br>③ `chat()` 日志补 `thinking` 字段 + 温度在思考模式下无效的注释 |
| `ai/app/adapters/model_gateway.py` | `chat_json` 默认值同步为 `disable_thinking=True`（网关层必须同步，否则覆盖下层） |
| `.env` / `ai/.env` | `LLM_MODEL` → `deepseek-flash`，并注明「DB > env」优先级 |
| `docker-compose.yml` | `LLM_MODEL` 兜底默认值 `generalv3.5` → `deepseek-flash` |
| `backend/.../db/migration/V51__llm_model_rename_deepseek_flash.sql` | 新增，幂等 UPDATE（Flyway 上线自动执行） |
| `ai/tests/integration/test_llm_capabilities.py` | 新增，4 个集成用例（默认跳过） |
| `ai/tests/conftest.py` | 修 `fake_chat_json` / `fake_chat` 桩签名，对齐转发参数 |

### 本地验证结果

| 验证项 | 结果 |
|---|---|
| 离线测试（unit + contract + security） | **86 passed, 4 skipped** |
| 集成测试（真实调 DeepSeek） | **4 passed**（8.2s） |
| AI 容器重启后生效模型 | `LLM=deepseek-flash` ✅（`/internal/config/status` 实查） |
| VISION | 保持 `qwen3-omni-flash`（未切换，等你拍板） |

---

## 7. 分工与上线清单

### ⚠️ 当前状态：代码已改完并放进暂存区，但**还没 commit / push**

原因：AI 侧执行 `git commit` 时进程卡死（创建 `.git/index.lock` 后不动，被系统强杀），
试了 `-m` / `-F 文件` / 关掉 gc 都无效，底层 `git write-tree` 同样卡；`git add` / `status` / `log` 全部正常。
**这是执行环境问题，不是你代码的问题。你的 7 个改动一个都没丢，全在暂存区里。**

所以**服务器没变是正常的** —— 服务器只认 GitHub 上的代码，不 push 就永远不变。

### 我已经做完（代码 + 配置）

A（本地 env + compose）、B、D、E、F、G —— 全部完成并本地验证，已 `git add` 进暂存区。

### 需要你自己做的（无需动代码）

| # | 事项 | 怎么做 | 为什么必须你做 |
|---|---|---|---|
| 1 | **线上服务器 `.env` 改 `LLM_MODEL=deepseek-flash`** | SSH 到 `/opt/zhiyu-new`，改 `.env` 后不需要单独重启（DB 会覆盖） | 我没有服务器访问权限；且属基础设施兜底 |
| 2 | **管理端新增一条 `deepseek-flash` 配置行**（P0-C） | 模型管理 → 新增：capability=`LLM`、base_url=`https://api.deepseek.com/v1`、model=`deepseek-flash`、填 Key → 先「连通性测试」→ 再「设激活」 | 涉及密钥录入，不该由我代劳；且保留旧行可做 AB 回退 |
| 3 | **决定 VISION 是否切到 DeepSeek** | 若切：改该行 base_url/model；同时 prod 要补 `VISION_ALLOWED_HOSTS` 白名单（MinIO 域名），否则 403 | 产品决策 + 生产白名单，需你确认 |
| 4 | **提交并推送** | `git add` → commit → push main（push 即触发 CI 部署） | 涉及生产发布，按项目铁律由你把关 |
| 5 | **上线后观察** | `docker logs zhiyu-ai \| grep -E "llm_chat_truncated\|thinking=true"` 观察 1 天 | 需要真实流量 |

### 上线顺序建议

```
1. 本地 commit + push（代码改动 + V51 迁移）
      ↓ CI 构建 → 服务器 pull 镜像 + docker compose up --profile web
      ↓ backend 启动 → Flyway 自动执行 V51（幂等，改 ai_model 行）
      ↓ AI 中台 30s 内热读到 deepseek-flash，零重启
2. 管理端「连通性测试」确认新模型可用
3. 观察 1 天日志，无 llm_chat_truncated 即收工
```

### 回退方式

- **代码回退**：`git revert` 或直接回滚 tag `v-contest-baseline`（本次未触碰该基线涉及的文件）
- **模型回退**：管理端把旧配置行「设激活」，30s 生效，无需重新部署
- **注意**：`chat_json` 默认关闭思维链属行为变更，若发现某些批阅/评分场景质量下降，
  在该调用点显式传 `disable_thinking=False` 并配足 `max_tokens` 即可局部恢复。

---

## 附录：多模态链路全量核查与修复（2026-09-10 晚）

### 一、四条多模态链路实测结论

用容器内探针（`ai/tests/vision_probe.py`，12 项断言）真实调模型核验：

| # | 链路 | 走的模型槽位 | 结论 |
|---|---|---|---|
| ① 问诊 图片分析 | `ai/app/api/vision.py` | **VISION** = `qwen3-omni-flash`（阿里云 MaaS） | 模型侧正常，**来源校验门有缺陷**（见下） |
| ② AI 学伴 发图 | `ai/app/workflows/companion_workflow.py` | **LLM** = `deepseek-flash` | 正常读图（探针实测返回完整描述） |
| ③ 备课素材图转写 | `ai/app/api/lesson.py` | **VISION** | 正常（仅校验 scheme，公网 URL 可用） |
| ④ 图像索引摘要 | `ai/app/services/image_index_service.py` | **VISION**，base64 内联 | 正常（不经来源校验） |

**"学伴能发图、问诊不能"的原因**：学伴走主 LLM 且**没有来源白名单校验**；
问诊走 VISION 槽位且**被白名单 + HTTPS 强制两道门拦下**。两者模型不同、校验不同，
不是"多模态能力缺失"。

**"VISION 要不要切 DeepSeek"**：不需要。VISION 是独立能力槽位，当前 `qwen3-omni-flash`
实测读图正常；DeepSeek 的视觉能力只作用于主 LLM 链路（即学伴）。切过去不会带来收益，
反而会让 VISION 与 LLM 抢同一份配额。

### 二、问诊图片发不出去的根因（两道门同时误伤）

`_validate_image_url()` 在生产环境执行：

1. **白名单比较口径不一致** → 恒 403
   `.env` 写 `VISION_ALLOWED_HOSTS=["http://8.160.161.158"]`，代码却用
   `urlparse(url).hostname`（裸主机名 `8.160.161.158`）做集合比较 → 永不相等。
2. **生产强制 HTTPS** → 422
   自建对象存储只有 `http://8.160.161.158` 的 IP+HTTP 入口，没有证书。

### 三、修复方案（最小改动，不加新环境变量）

让**白名单条目自带协议**，语义取自运维的显式声明：

- 裸主机名 `storage.example.com` → 仅允许 **https**（安全默认，不放松）
- 完整 URL `http://8.160.161.158` → 允许 **http**（合法 HTTP 图床场景）

改动文件：

| 文件 | 改动 |
|---|---|
| `ai/app/core/config.py` | 新增 `vision_allowed_origins` 属性：归一化为 `{主机名: 允许协议集合}`；生产校验改用它 |
| `ai/app/api/vision.py` | 按主机名取允许协议集合；协议不在集合内才 422 |
| `.env.example` | 补充两种白名单写法说明 |
| `ai/tests/security/test_vision_url_guard.py` | 新增 9 项安全回归用例 |
| `ai/tests/integration/test_vision_e2e.py` | 新增 2 项端到端用例（默认跳过） |
| `ai/tests/vision_probe.py` | 新增 12 项链路探针（诊断工具） |

**服务器 `.env` 无需任何改动** —— 现有 `["http://8.160.161.158"]` 修复后即可命中。

### 四、验证证据

- 探针：**12/12 通过**（4 条链路读图 + 白名单/协议/内网边界矩阵）
- 单测/契约/安全：**96 passed, 4 skipped**；加集成用例共 **96 passed, 10 skipped**
- 端到端（真实 HTTP 路由 + 真实模型，prod 配置）：
  - 白名单命中 → `200`，`source=VISION_LLM`、`degraded=False`，返回真实读图结论
  - 白名单未命中 → `403 图片来源不在允许范围内`（安全边界保留）

### 五、顺带发现的观察项（未改动，待你拍板）

主 LLM 的**流式**路径（`llm_client.stream`）不传 `disable_thinking`，即思考模式恒开启，
且预算 = `LLM_MAX_TOKENS`（2048，各 Agent 均未热配覆盖）。实测读一张图约耗 1314 token
（其中思考 449），**余量不宽**。若将来把图片分辨率调高或给 Agent 配更小的
`max_tokens`，可能出现「学伴回复空白」——届时需给流式路径补 `disable_thinking` 开关。
