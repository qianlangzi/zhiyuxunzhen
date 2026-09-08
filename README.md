# 🩺 智愈寻真

**新医科 AI 教研协同智能体平台** —— *让 AI 走进内科教学的每一个环节：学 · 练 · 诊 · 教 一体化*

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white) ![Spring Boot](https://img.shields.io/badge/Spring%20Boot-3.x-6DB33F?logo=springboot&logoColor=white) ![FastAPI](https://img.shields.io/badge/FastAPI-LangGraph-009688?logo=fastapi&logoColor=white) ![Vue 3](https://img.shields.io/badge/Vue%203-管理端-4FC08D?logo=vuedotjs&logoColor=white) ![MySQL](https://img.shields.io/badge/MySQL-8-4479A1?logo=mysql&logoColor=white) ![Milvus](https://img.shields.io/badge/Milvus-向量检索-00A1E0?logo=milvus&logoColor=white) ![Docker](https://img.shields.io/badge/Docker%20Compose-一键部署-2496ED?logo=docker&logoColor=white) ![License](https://img.shields.io/badge/License-MIT-yellow)

---

## 📖 目录

- [项目简介](#-项目简介)
- [核心功能](#-核心功能)
- [系统架构](#-系统架构)
- [技术栈](#-技术栈)
- [项目结构](#-项目结构)
- [快速开始](#-快速开始)
- [部署上线](#-部署上线)
- [数据库演进](#-数据库演进)
- [赛事信息](#-赛事信息)
- [Roadmap](#-roadmap)

---

## 💡 项目简介

> **为什么做「智愈寻真」？**

传统内科临床教学长期存在三大痛点：

| 痛点 | 现状 | 智愈寻真的解法 |
|------|------|----------------|
| 😩 **病例资源少** | 真实病例稀缺，学生练手机会有限 | 🤖 AI 生成标准化病人（SP）与病例，**每日一例**永不断更 |
| 🧑‍🏫 **教师负担重** | 备课、批改、学情分析全靠人力 | 📚 AI 智能备课 + 主观题自动批改 + 学情自动预警 |
| 🔍 **反馈不精准** | "错在哪、为什么错"无从得知 | 🧠 **思维分叉归因**引擎，把每个错误拆解到认知层面 |

**智愈寻真** 是一套面向医学院校内科学教学的**四端协同**平台：
学生端（Flutter App）负责学、练、诊；教师端（Flutter App）负责教、管、析；
Web 管理端（Vue 3）负责内容与系统治理；AI 中台（FastAPI + LangGraph）是驱动一切的智能引擎。

> 🗣️ `AI 知识问答` · 📚 `智能备课` · 🚨 `学情预警` · 📝 `主观题批改` · 🧑‍⚕️ `SP 问诊训练` · ✍️ `病历书写教练`

---

## ✨ 核心功能

### 👨‍🎓 学生端 —— 学 · 练 · 诊

| 功能 | 亮点 |
|------|------|
| 📅 **每日一例（病历训练）** | 每天推送一份 AI 病例，**边写 → 边导 → 边判 → 沉淀**：病历九段拆解、逐段 AI 教练实时点评、结构化缺陷标签、修订版本对比 |
| 💬 **SP 问诊训练** | 与 AI 扮演的标准化病人对话问诊，Socratic 式引导提示，问诊结束后生成多维度评分报告 |
| 🧠 **错题本 · 思维分叉归因** | 不止记录"错"，更回答"**为什么错**"——五阶段认知归因 + 认知偏差识别 + 分叉点定位，错题入库即异步生成归因结论，并回流到个性化推荐 |
| 📊 **成长热力图 & 学情画像** | 考点掌握度可视化，三路加权考点优先级（教师权重 40% + 数据权重 40% + LLM 知识权重 20%），红/黄/灰三色标示复习优先级 |
| 💊 **药物库训练** | 内科用药知识专项训练 |
| 🏥 **病例大厅** | 全院病例资源市场，按科室浏览与引用 |
| ✅ **待办中心** | 作业、资料任务与课程联动，完成即清零 |

### 👩‍🏫 教师端 —— 教 · 管 · 析

| 功能 | 亮点 |
|------|------|
| 📚 **AI 智能备课** | 上传 PDF / PPT / MP4 / MP3 课件，AI 辅助生成教案；课件可独立下发给学生，也可绑定作业 |
| 📝 **主观题智能批改** | 简答 / 论述题 / 大病历自动批改，支持**教师自定义评分要点**，AI 初筛 + 人工复核 |
| 🚨 **学情预警** | 基于错题、病历缺陷、作业数据的学情诊断，预警消息走**站内信**直达学生 |
| 🗺️ **班级缺陷热力图** | 病历训练 AI 初筛结果聚合，全班知识薄弱点一图看清 |
| 🧑‍⚕️ **自定义 SP 病人** | 教师可创建自定义标准化病人，供问诊训练与病例大厅引用 |
| 📋 **作业管理** | 组卷 Agent 一键生成巩固卷、布置作业、跟踪完成进度 |

### 🖥️ Web 管理端 —— 治 · 控

用户与班级治理、题库与病例内容管理、Prompt 配置中心（`ai_prompt` 表热更新，30s 轮询生效）、系统运维监控。

### 🤖 AI 中台 —— 智能引擎

- **LangGraph 多智能体编排**：问答讲解、组卷、批改、归因、备课各司其职
- **RAG 知识库**：DashScope Embedding + Milvus 向量检索，答案有据可依
- **Prompt 中台化**：全部提示词入库管理，改 Prompt 不用改代码、不用重启服务
- **异步任务队列**（ai-worker）：归因、批改、诊断等重任务异步执行，主链路零阻塞

---

## 🏗️ 系统架构

```
┌───────────────────────────── 客户端层 ─────────────────────────────┐
│   📱 学生端 (Flutter)     📱 教师端 (Flutter)    🖥️ Web 管理端 (Vue3) │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ HTTP / REST
┌──────────────────────────────▼──────────────────────────────────────┐
│              ☕ 业务服务层  zhiyu-backend                             │
│         Spring Boot 3 · MyBatis-Plus · JWT · Flyway 迁移             │
└──────────┬───────────────────────────────────────────┬──────────────┘
           │ AI 请求转发                                │ 业务读写
┌──────────▼───────────────────┐        ┌──────────────▼──────────────┐
│  🧠 AI 中台 zhiyu-ai          │        │  🗄️ 基础设施层               │
│  FastAPI + LangGraph         │        │  MySQL 8 · Redis            │
│  多智能体编排 · RAG 检索增强    │        │  Milvus + etcd + MinIO      │
└──────────┬───────────────────┘        └──────────────▲──────────────┘
           │ 异步任务                                   │
┌──────────▼───────────────────┐                       │
│  ⚙️ ai-worker 异步任务队列     │───────────────────────┘
│  归因 / 批改 / 学情诊断        │
└──────────────────────────────┘
```

**一次"错题归因"的完整链路**：

```
学生答题 → 后端判分入库 → 投递异步任务 → ai-worker 调用 LangGraph 归因 Agent
        → 五阶段分析 + 认知偏差识别 + 分叉点定位 → 结果写回 ai_analysis_json
        → 回流学情诊断 & 个性化推荐 → 学生打开错题本，归因已就绪
```

---

## 🛠️ 技术栈

| 分层 | 技术 | 说明 |
|------|------|------|
| 📱 移动端 | Flutter 3 · Riverpod · GoRouter · Dio | 学生端 / 教师端双端复用一套工程，浅色 / 深色 / 自动三态主题 |
| 🖥️ 管理端 | Vue 3 · Vite · TypeScript | 内容与系统治理后台 |
| ☕ 后端 | Spring Boot 3 · MyBatis-Plus · Flyway · JWT | 业务 API、权限、任务调度、AI 请求转发 |
| 🧠 AI 中台 | FastAPI · LangGraph · DashScope Embedding · DeepSeek | 多智能体编排、RAG 检索增强生成 |
| 🗄️ 存储 | MySQL 8 · Redis · Milvus · MinIO · etcd | 业务数据 / 缓存 / 向量库 / 对象存储 / Milvus 协调 |
| 🐳 DevOps | Docker Compose（11 服务）· GitHub Actions CI/CD | push 到 main 即自动构建部署 |

---

## 📂 项目结构

```
zhiyu/
├── 📱 mobile/          # Flutter 移动端（学生端 + 教师端）
│   └── lib/
│       ├── core/               # API 配置中心、网络层、主题体系
│       ├── features/
│       │   ├── auth/           # 登录认证（支持生物识别）
│       │   ├── student/        # 学生端：每日一例 / 问诊 / 错题本 / 药物库…
│       │   ├── teacher/        # 教师端：备课 / 预警 / 批改 / 作业管理…
│       │   └── common/         # 新手引导、公共组件
│       └── app.dart            # 路由 + 三态主题
├── ☕ backend/         # Spring Boot 业务后端
│   └── src/main/resources/db/migration/   # Flyway 增量迁移脚本（V1 → V45+）
├── 🧠 ai/              # FastAPI + LangGraph AI 中台（含 ai-worker 异步队列）
├── 🖥️ front/           # Vue 3 Web 管理端
├── 🐳 docker-compose.yml        # 开发编排（MySQL/Redis/Milvus/etcd/MinIO/…）
├── 🚀 docker-compose.prod.yml  # 生产覆盖层（多阶段构建 + nginx）
└── ⚙️ .github/workflows/deploy.yml   # CI/CD：push main → 自动部署
```

---

## 🚀 快速开始

### 0️⃣ 环境要求

| 依赖 | 版本要求 |
|------|----------|
| Docker & Docker Compose | v2.x |
| JDK | 17 |
| Flutter SDK | 3.x |
| Node.js | 18+（仅管理端开发需要） |

### 1️⃣ 启动基础设施与后端

```bash
# 克隆项目
git clone https://github.com/<your-org>/zhiyuxunzhen.git
cd zhiyu

# 启动全部服务（开发模式，含 Web 管理端）
docker compose --profile web up -d --build

# 查看服务状态
docker compose ps
```

> 后端首次启动时 Flyway 会自动执行全部数据库迁移脚本，无需手动建表。
> 生产环境需额外准备 `.env`（`JWT_SECRET` / `AI_INTERNAL_TOKEN` / `CORS_ALLOWED_ORIGINS` / `OPS_TOKEN`），**任何密钥都不入库不入仓**。

### 2️⃣ 运行移动端

```bash
cd mobile

# 模拟器：默认连宿主机后端（10.0.2.2:18080）
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:18080

# 真机：连局域网内电脑上的后端
flutter run --dart-define=API_BASE_URL=http://<你的局域网IP>:18080
```

### 3️⃣ 打 Release 包（直连线上服务器）

```bash
flutter build apk --release --dart-define=API_BASE_URL=http://<服务器地址>
# 产物：mobile/build/app/outputs/flutter-apk/app-release.apk
```

> API 地址通过 `--dart-define` 构建期注入（见 `mobile/lib/core/config/api_config.dart`），**切换环境无需改一行代码**。

### 4️⃣ 运行 AI 中台（独立开发时）

```bash
cd ai
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

---

## 🚢 部署上线

项目采用 **GitHub Actions 全自动部署**：

```
push 到 main 分支
   │
   ▼
GitHub Runner 通过 SSH 连接服务器
   │
   ▼
git pull → docker compose（prod 覆盖层 + web profile）up -d --build
   │
   ▼
镜像重建 → 容器滚动更新 → 旧镜像自动清理
```

- 服务器敏感信息（SSH 主机/账号/密码）全部走 **GitHub Repository Secrets**，仓库内零硬编码
- AI 中台源码挂载 + uvicorn reload，开发期改代码即时生效
- 手动部署支持 workflow_dispatch 一键触发

---

## 🗄️ 数据库演进

- 全部表结构变更通过 **Flyway 增量迁移**管理（`V1__` 至今 45+ 个脚本）
- 铁律：**只增不改不删**——保持向后兼容，禁止修改已执行的历史脚本
- 核心业务表：用户/班级/作业、错题本（含 AI 归因 JSON）、每日病历排期与缺陷、考点权重、SP 病人、Prompt 配置中心等

---

## 🏆 赛事信息

本项目参加 **XH-202620 学科垂类大模型与创新应用开发大赛**，赛道：**助教 / 助学**。

围绕"AI 赋能医科教学"交付四大核心能力：

> 🗣️ **AI 知识问答与讲解** · 📚 **智能备课** · 🚨 **学情预警** · 📝 **主观题批改**

---

## 🗺️ Roadmap

✅ 学生端 / 教师端四 Tab 信息架构定型
✅ 每日病历训练闭环（九段拆解 + 逐段 AI 教练 + 缺陷标签）
✅ 错题本思维分叉归因全链路（异步预生成 + 回流推荐）
✅ 待办 ↔ 我的课程 同源联动
✅ 新手引导（自研零依赖引导遮罩，按角色分组播放）
⬜ 主观题错题入库 & AI 归因覆盖 essay / short_answer
⬜ 每日病历缺陷入错题本
⬜ 考点优先级三路加权推荐全量上线
⬜ iOS 端适配与上架

---

## 🤝 贡献

欢迎 Issue 与 PR！提交前请确保：

1. 后端：`mvn -q clean package -DskipTests` 通过
2. 移动端：`flutter analyze` 无 error / warning
3. 数据库变更只新增 Flyway 增量脚本

## 📄 License

MIT © 智愈寻真团队

---

**智愈寻真** —— *于病案之间，寻诊疗之真* 🩺
