# 真实环境配置准备清单

本清单按准备顺序填写。密钥只写入服务器 `.env` 或密钥管理服务，不提交 Git。

## 现在必须准备

### JWT_SECRET

用途：Spring Boot 签发登录令牌，FastAPI 验证同一个令牌。两边必须完全相同，建议至少 32 字节随机值。

```powershell
python -c "import secrets; print(secrets.token_urlsafe(48))"
```

### AI_INTERNAL_TOKEN

用途：Spring Boot 与 FastAPI 内部接口鉴权。两边必须完全相同，使用独立随机值，不能与 JWT_SECRET 相同。

### OPS_TOKEN

用途：访问 FastAPI `/status`。仅交给运维人员，不放进移动端、Web 或 Spring Boot 返回值。

### CORS_ALLOWED_ORIGINS

用途：允许哪些 Web 域名访问 FastAPI。填写完整 Origin，不带路径，例如：

```env
CORS_ALLOWED_ORIGINS=["https://teacher.example.com","https://admin.example.com"]
```

移动 App 不依赖浏览器 CORS。

### BACKEND_CALLBACK_URL

用途：FastAPI 调用 Spring Boot 内部接口。Docker Compose 内保持 `http://backend:8080`；跨机器部署时填写只能被内网访问的 HTTPS 地址。

## 基础设施配置

### Redis

需要主机、端口、密码、数据库编号。用于异步任务、幂等和任务状态。生产必须启用密码、网络白名单和持久化。

```env
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=<随机强密码>
REDIS_DB=0
```

### Milvus

需要主机、端口、collection 和向量维度。`MILVUS_VECTOR_DIM` 必须与未来选择的 Embedding 模型输出维度一致，不能凭感觉填写。

```env
MILVUS_HOST=milvus
MILVUS_PORT=19530
MILVUS_COLLECTION=zhiyu_textbook
MILVUS_VECTOR_DIM=<由Embedding模型决定>
```

### 对象存储

当前开发环境可直接使用：

```env
OBJECT_STORAGE_ROOT=./data/objects
OBJECT_STORAGE_MAX_BYTES=52428800
```

教材放到 `data/objects/textbooks/` 后，接口只传 `textbooks/文件名.pdf`。生产需要从 MinIO、阿里云 OSS、腾讯云 COS 或 AWS S3 中选择一种，准备 endpoint、bucket、region、access key、secret key；不要把 bucket 设为公开写入。

## AI 服务确定后再准备

### LLM

需要确认供应商、OpenAI 兼容 Base URL、API Key、模型名、上下文长度、限流和计费方式。

```env
LLM_BASE_URL=
LLM_API_KEY=
LLM_MODEL=
```

当前保持空即可。为空时不能生成正式批阅、评分和报告。

### Embedding

需要 Base URL、API Key、模型名和输出维度。选择后必须同步修改 `MILVUS_VECTOR_DIM` 并重新建立 collection。

```env
EMBEDDING_BASE_URL=
EMBEDDING_API_KEY=
EMBEDDING_MODEL=
```

### Vision

需要多模态模型 Base URL、API Key、模型名，以及图片对象存储域名白名单。Vision 未启用时这些字段可以留空。

```env
VISION_BASE_URL=
VISION_API_KEY=
VISION_MODEL=
VISION_ALLOWED_HOSTS=["storage.example.com"]
```

## 上线前必须确认

- `ENV_MODE=prod`
- `ENABLE_LLM_FALLBACK=false`
- `ENABLE_MILVUS_FALLBACK=false`
- 所有默认 Token 已替换
- `.env` 未进入 Git
- Redis、Milvus、Spring Boot 只能通过内网访问
- `/status` 无 `X-Ops-Token` 时返回 401
- `/health/live` 和 `/health/ready` 已接入容器健康检查
