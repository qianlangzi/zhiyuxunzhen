# ===== Stage 1: 构建 =====
FROM python:3.11-slim AS builder
WORKDIR /build

# 国内 pip 源加速
RUN pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple

COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# ===== Stage 2: 运行 =====
FROM python:3.11-slim
WORKDIR /app

# 复制构建阶段安装的包
COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH

COPY app ./app

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
