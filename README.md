# 智愈寻真 · 内科教研协同智能体平台

> 内科教研 AI 训练平台脚手架。需求见 [docs/PRD_V1.0.md](docs/PRD_V1.0.md)。

## 技术架构

```
┌──────────────────────────────────────────────────────────┐
│                     生产环境架构                          │
│                                                          │
│  用户浏览器 ──→ Nginx (:80) ──┬── /          → front     │
│                               ├── /api/v1/   → backend   │
│                               └── /api/v1/ai → ai (SSE)  │
│                                                          │
│                     开发环境架构                          │
│                                                          │
│  浏览器 ──→ Vite (:5173) ──┬── /api/* → backend (:8080)  │
│              proxy          └── /ai/*  → ai      (:8000) │
│                                                          │
│  Backend ─┬─→ MySQL 8.0           :3306                 │
│           └─→ (HTTP 回调) → AI                          │
│  AI ───────→ Milvus Standalone    :19530                 │
└──────────────────────────────────────────────────────────┘
```

## 目录结构

```
E:\zhiyu\
├── docker-compose.yml              # 基础配置(所有环境共用)
├── docker-compose.override.yml     # 开发环境覆盖(自动合并)
├── docker-compose.prod.yml         # 生产环境覆盖(需 -f 指定)
├── .env / .env.example             # 环境变量
├── .gitignore
├── docs/PRD_V1.0.md                # 产品需求
│
├── deploy/                         # 基础设施配置
│   ├── mysql/
│   │   ├── init.sql                # PRD 第七章 9 张表建表 SQL
│   │   └── my.cnf                  # MySQL 字符集/性能配置
│   ├── milvus/
│   │   └── milvus.yaml             # Milvus Standalone 配置
│   └── nginx/
│       └── nginx.conf              # 根级反向代理(生产环境核心)
│
├── data/                           # 本地数据挂载(仅开发,勿提交 Git)
│   ├── mysql/                      # MySQL 数据文件
│   └── milvus/                     # Milvus 持久化数据
│
├── logs/                           # 日志归集(勿提交 Git)
│   ├── backend/                    # Java 运行日志
│   └── ai/                         # Python 运行日志
│
├── front/                          # Vue 3 前端
│   ├── Dockerfile                  # 生产:多阶段构建 → Nginx
│   ├── Dockerfile.dev              # 开发:Vite dev server + HMR
│   ├── nginx.conf                  # 前端容器内 Nginx 配置
│   ├── vite.config.ts              # 开发期 proxy
│   ├── src/views/Home.vue          # 健康检查页
│   ├── src/views/Login.vue         # 登录页
│   ├── src/api/index.ts            # axios 封装
│   └── src/stores/user.ts          # Pinia 用户态
│
├── backend/                        # Spring Boot 业务中台
│   ├── Dockerfile
│   ├── pom.xml
│   └── src/main/java/com/zhiyu/
│       ├── ZhiyuApplication.java
│       ├── controller/             # Health / User
│       ├── service/                # 业务(示例:登录)
│       ├── mapper/                 # MyBatis Plus
│       ├── entity/                 # 实体
│       └── config/                 # 跨域等配置
│
└── ai/                             # FastAPI AI 中台
    ├── Dockerfile
    ├── requirements.txt
    └── app/
        ├── main.py                 # FastAPI 入口
        ├── api/
        │   ├── chat.py             # SSE 流式(PRD 4.2)
        │   └── health.py           # 健康检查
        └── core/config.py          # 全局配置
```

## 一键切换:开发环境 ↔ 生产环境

### 开发环境(默认)

Docker Compose 默认自动合并 `docker-compose.override.yml`，无需额外参数：

```powershell
# 启动(自动合并 override)
docker compose up -d --build

# 停止
docker compose down
```

**开发环境特性**：
| 特性 | 说明 |
| --- | --- |
| 前端 HMR | Vite dev server,改代码浏览器自动刷新 |
| AI 热重载 | uvicorn --reload,改 Python 自动重启 |
| 端口全暴露 | MySQL:3306 / Milvus:19530 / 后端:8080 / AI:8000 / 前端:5173 |
| 数据本地化 | MySQL 数据存 `data/mysql/`,方便用 Navicat 直连 |
| 日志本地化 | Java/Python 日志存 `logs/` 目录 |

### 生产环境

需显式指定 prod 配置文件，**同时排除 override**：

```powershell
# 启动生产环境
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build

# 停止
docker compose -f docker-compose.yml -f docker-compose.prod.yml down
```

**生产环境特性**：
| 特性 | 说明 |
| --- | --- |
| 统一入口 | 根级 Nginx 反向代理,所有流量走 80 端口 |
| 前端 | 多阶段构建 → Nginx 托管静态文件 |
| AI | uvicorn 4 worker,无 --reload |
| 端口不暴露 | MySQL/Milvus 不对宿主机暴露,仅容器网络可达 |
| 资源限制 | 每个服务设 memory limit |
| 数据卷 | Docker volume 而非本地目录 |
| 健康检查 | Nginx + MySQL 均配 healthcheck |

### 对比速查

| | 开发环境 | 生产环境 |
| --- | --- | --- |
| 启动命令 | `docker compose up -d --build` | `docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build` |
| 前端 | Vite dev server :5173 (HMR) | Nginx 静态文件 :80 |
| AI | uvicorn --reload | uvicorn --workers 4 |
| 根级 Nginx | 无 | 有,统一反代 |
| MySQL 端口 | 暴露 :3306 | 不暴露 |
| 数据存储 | `./data/mysql/` 本地目录 | Docker volume |
| 资源限制 | 无 | 有 |

## 第一次启动(小白 5 步走)

### ① 确认 Docker Desktop 已运行

- 任务栏右下角有鲸鱼图标
- 推荐在 **Settings → Resources → Advanced** 把 Disk image location 改到 D 盘(避免 C 盘占满)

### ② 复制环境变量

```powershell
cd E:\zhiyu
copy .env.example .env
```

> 暂时不用改,默认值就能跑起来。`SPARK_API_KEY` 等接入星火大模型时再填。

### ③ 一键启动开发环境

```powershell
docker compose up -d --build
```

> 第一次会拉基础镜像 + 构建,大概 5-10 分钟。看日志:
> ```powershell
> docker compose logs -f
> ```

### ④ 验证

| 服务 | 地址 | 期望 |
| --- | --- | --- |
| 前端 | http://localhost:5173 | 看到蓝色头部 + 健康检查卡片 |
| 后端 | http://localhost:8080/api/v1/health | 返回 `{"code":0,"data":{"status":"UP","db":"UP"}}` |
| AI | http://localhost:8000/docs | 看到 FastAPI Swagger 页面 |
| MySQL | localhost:3306 | 用 Navicat / DBeaver 连接,root/root123456 |

### ⑤ 登录

打开 http://localhost:5173/login,默认账号:
- 教师:`teacher01` / `123456`
- 学生:`student01` / `123456`

## 日常开发循环

```powershell
# 改了前端代码 → Vite HMR 自动刷新,无需手动 rebuild
# 改了 AI Python → uvicorn --reload 自动重启,无需手动 rebuild

# 改了后端 Java → 必须重新 build(容器内是 fat jar)
docker compose up -d --build backend

# 查看某服务日志
docker compose logs -f ai

# 进容器内部调试
docker compose exec backend sh

# 全部推倒重来(会清掉 MySQL 数据!)
docker compose down -v
```

## 下一步要补的功能(按 PRD 优先级)

| 优先级 | 模块 | 涉及文件 |
| --- | --- | --- |
| P0 | SP 配置台(教师) | `backend/controller/CaseController.java` + `front/views/teacher/CaseCreate.vue` |
| P0 | 多模态问诊室(学生) | `ai/app/api/chat.py`(替换 mock) + `front/views/student/Chat.vue` |
| P0 | 接入星火大模型 | `ai/app/core/spark_client.py`(新增) |
| P1 | 智能批阅 | `ai/app/api/review.py`(新增) |
| P1 | 思维决策树 SSE 事件 | 已留骨架,见 `ai/app/api/chat.py:_mock_stream` |
| P2 | 教材向量化 | `ai/app/api/embed.py` |
| P2 | 学习路径生成 | `ai/app/api/learning_path.py` |
| P2 | OSCE 雷达图 | `front` 用 ECharts |

## 常见问题

**Q: 容器起不来,报 "port is already allocated"?**
A: 3306 / 8080 / 8000 / 5173 / 19530 端口被本地已安装的 MySQL / Nginx / Node 占了。
   - 方案 A:停止本地对应服务
   - 方案 B:在 `.env` 里把对应 `*_PORT` 改大,例如 `BACKEND_PORT=18080`

**Q: docker compose build 超时?**
A: Dockerfile 里已经加了国内镜像加速。如仍超时,检查 Docker Desktop → Settings → Docker Engine 里的 `registry-mirrors`。

**Q: 改了后端 Java 代码没生效?**
A: Spring Boot 在容器内是 fat jar 模式,**改了代码必须重新 build**:`docker compose up -d --build backend`

**Q: 改了前端/AI 代码也没生效?**
A: 开发环境已挂载源码 + 开启热重载,应该自动生效。如不生效,检查容器是否正常运行:`docker compose ps`

**Q: 数据库连不上?**
A: 等 `mysql` 容器 healthcheck 通过后再访问,大概 30-60 秒。

**Q: 生产环境怎么配 HTTPS?**
A: 1) 在 `deploy/nginx/certs/` 放证书;2) 在 `deploy/nginx/nginx.conf` 加 443 server 块;3) 取消 `docker-compose.prod.yml` 里 443 端口和证书挂载的注释。

**Q: 怎么从开发切到生产?**
A: 先停掉开发环境,再用 prod 命令启动:
```powershell
docker compose down
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
```
