# VISION 链路收敛 DeepSeek 设计方案

> 2026-09-09 起草 · 状态：待拍板
> 背景：deepseek-chat 已于 2026-07-24 官方停用（LLM 已切 deepseek-v4-flash）；V4.1 Flash 计划 2026-09-10 前后发布，新架构原生多模态，可承接 VISION 能力。

## 一、现状盘点

### 当前模型矩阵（ai_model 表）

| 能力 | 模型 | 供应商 | 状态 |
|---|---|---|---|
| LLM | deepseek-v4-flash（2026-09-09 已切） | DeepSeek | ✅ 已验证热切换 |
| VISION | qwen3-omni-flash | 阿里云 MaaS（专属推理端点） | 待收敛 |
| EMBEDDING | BAAI/bge-m3 | SiliconFlow | 本次不动 |
| EMBEDDING_MULTI | qwen3-vl-embedding | 阿里云 MaaS | 本次不动（embedding 与 chat 是两条独立链路） |

### VISION 代码使用点（共 3 处，全部读 `settings.vision_*`）

| 使用点 | 场景 | 输入格式 |
|---|---|---|
| `app/api/vision.py` `/v1/ai/vision/analyze` | 问诊 SP 学生上传图片读图 | HTTP(S) image_url（有 VISION_ALLOWED_HOSTS 安全校验） |
| `app/api/lesson.py` | 备课课件图片理解 | 同上 |
| `app/services/image_index_service.py` | 图片入库时的视觉索引 | 同上 |

**关键结论：三个使用点全部走 OpenAI 兼容 ChatCompletions + image_url 消息格式，切换供应商 = 只改 `ai_model` 表 VISION 行（base_url / api_key / model），代码零改动。** ModelRegistry 30s 热生效，自带回退（DB 停用该行即回 .env 基线）。

## 二、目标模型选择

### 时间线约束（官方 Change Log 已核实）

- 现在官方多模态可用 ID 只有 **`deepseek-v4-flash-vision-exp`**（8/21 发布，实验版，图片输入文本输出，9/31 开源权重）
- **V4.1 Flash（9/10 前后发布）原生多模态**，架构级内置视觉能力，不再是实验分叉——这才是收敛的正主
- 新价格 9/10 12:00 生效：错峰输入未命中 ¥1/M、输出 ¥4/M，高峰 2 倍（对比现在 Flash 峰值输入 ¥3.16/M 输出 ¥9.48/M，显著降本）

### 建议：不切 vision-exp，等 V4.1 Flash 正式 ID

理由：vision-exp 是实验版（无 SLA、能力仅限视觉 Agent 场景、文本性能与普通 Flash 持平）；V4.1 Flash 原生多模态且「全面超越 V4 Pro」，等 1 天拿正式版，避免切两次。

## 三、分阶段计划

### D0（今天，已完成 ✅）
- LLM 切 `deepseek-v4-flash`：本地 ai_model 已改 + 三处 .env 基线已改 + 运行态快照已确认 + API 真调用冒烟通过
- **待办：生产服务器（阿里云 ECS /opt/zhiyu-new）同款操作**，二选一：
  - 管理端「模型管理」→ LLM 行编辑 model 为 `deepseek-v4-flash` → 激活（推荐，有操作留痕）
  - 或 SSH 执行：`docker exec zhiyu-mysql mysql -uroot -p$MYSQL_ROOT_PASSWORD zhiyu_db -e "UPDATE ai_model SET model='deepseek-v4-flash', updated_at=NOW() WHERE capability='LLM';"`
  - 30s 内热生效，无需重启任何容器

### D1（明天，V4.1 Flash 发布后）
1. LLM 切 `deepseek-v4.1-flash`（以官方公告的确切 ID 为准，留意是否有 `-expires-on-xxx` 过渡命名）
2. 验证回归：
   - AI 问答/讲解（chat_workflow）一轮
   - 错题归因（五阶段 stage / biasType 结构化输出是否仍稳定）
   - 主观题批改、学情预警洞察各一轮
   - 观察 thinking effort 默认档（high）下的延迟与成本，必要时按场景分层：批改/归因用 max，陪护闲聊用 low
3. 多模态连通性测试：用现有 vision_analyze 的图片直链直接对 V4.1 Flash 发 image_url 请求，验证格式兼容

### D2（D1 验证通过后）
1. VISION 行切 DeepSeek：`base_url=https://api.deepseek.com/v1`，api_key 复用 DEEPSEEK_API_KEY，model=V4.1 Flash 正式多模态 ID
2. VISION 场景回归：问诊读图（含 VISION_ALLOWED_HOSTS 校验路径）、备课图片理解、图片索引重建一条
3. 观察一周后：阿里 MaaS 专属端点若不再有其他用途（EMBEDDING_MULTI 仍在用！），仅可下线 vision 相关资源，**MaaS 账号不能销**

## 四、风险与回退

| 风险 | 概率 | 缓解 |
|---|---|---|
| V4.1 Flash 发布延期/更名 | 中 | D1 当天先查官方 Change Log 确认确切 ID；LLM 留在 v4-flash 无损 |
| 多模态 image_url 格式不兼容（如要求 base64） | 低 | D1 连通性测试先行；不行则 image_index_service 加 base64 转换层（唯一可能改代码的点） |
| 新模型结构化输出（chat_json）稳定性回归 | 中 | D1 回归清单覆盖错题归因/批改；异常则 thinking effort 调 high/max |
| 切换后效果变差 | — | ModelRegistry 自带回退：DB 停用该行即回 .env 基线；VISION 回退只需把行改回 qwen3-omni-flash |
| EMBEDDING_MULTI 误伤 | — | 明确不动 DashScope embedding 链路，向量入库格式与维度（qwen3-vl-embedding）与 chat 模型无关 |

## 五、收益小结

- 供应商从 3 家收敛到 2 家（DeepSeek 全包 chat+vision，SiliconFlow 只留 bge-m3；DashScope 只留 embedding）
- 成本：V4.1 Flash 新单价 + 峰谷分离，LLM/VISION 合并计费账户
- 运维：模型热切换继续走管理端一键操作，密钥只管 DeepSeek + SiliconFlow + DashScope 三把
