# syntax=docker/dockerfile:1
# MMORE Dockerfile（CPU 模式，远程 Embedding API，无需 GPU）
FROM ubuntu:22.04

# 系统依赖（libreoffice + weasyprint + GTK + tesseract OCR）
# 先切换清华镜像源加速下载，并开启重试与缺失修复以提高网络抖动下的成功率
RUN sed -i 's@//.*archive.ubuntu.com@//mirrors.tuna.tsinghua.edu.cn@g; s@//security.ubuntu.com@//mirrors.tuna.tsinghua.edu.cn@g' /etc/apt/sources.list && \
    apt-get update -o Acquire::Retries=5 && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends --fix-missing -o Acquire::Retries=5 \
      tzdata curl git ffmpeg libsm6 libxext6 libnss3 \
      libxi6 libxrandr2 libxcomposite1 libxcursor1 libxdamage1 libxfixes3 libxrender1 \
      libasound2 libatk1.0-0 libgtk-3-0 libreoffice libjpeg-dev libpango-1.0-0 \
      libpangoft2-1.0-0 weasyprint \
      tesseract-ocr tesseract-ocr-chi-sim \
      python3.11 python3.11-venv python3-pip && \
    ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 安装 MMORE（从 BuildKit 命名上下文引用实验仓库源码）
# 只装 process+cpu 最小集：业务用 fast 模式（仅 pymupdf 提取），
# 不需要 all 全家桶（rag/llm/colvision 里的 gliner/onnxruntime 等重型 ML 依赖）
COPY --from=repo / /app/mmore_repo

# 1) 移除系统 distutils 安装的 sympy/mpmath——pip 无法卸载它们，
#    否则 torch 升级依赖时报 "Cannot uninstall ... distutils installed project"
# 2) 从 PyPI CPU 索引装纯 CPU 版 torch（避免默认拉取数 GB 的 CUDA/nvidia 库）
# 3) 安装 mmore 的 process+cpu 最小依赖集 + API 包装器
RUN apt-get remove -y python3-sympy python3-mpmath 2>/dev/null; \
    pip3 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple && \
    cd /app/mmore_repo && \
    pip3 install --no-cache-dir --upgrade pip && \
    pip3 install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cpu && \
    pip3 install --no-cache-dir ".[process,cpu]" && \
    pip3 install --no-cache-dir fastapi uvicorn python-multipart

# 安装 API 包装器
COPY mmore_api.py /app/mmore_api.py

ENV PYTHONPATH="/app/mmore_repo/src:/app"
ENV DASK_DISTRIBUTED__WORKER__DAEMON=False

EXPOSE 8002

CMD ["python3", "/app/mmore_api.py"]
