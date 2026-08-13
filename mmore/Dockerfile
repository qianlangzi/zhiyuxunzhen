# MMORE Dockerfile（CPU 模式，远程 Embedding API，无需 GPU）
FROM ubuntu:22.04

# 系统依赖（libreoffice + weasyprint + GTK + tesseract OCR）
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
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

# 安装 MMORE（从本地源码）
COPY repo /app/mmore_repo
RUN cd /app/mmore_repo && \
    pip3 install --no-cache-dir -e ".[all,cpu]" && \
    pip3 install --no-cache-dir fastapi uvicorn python-multipart

# 安装 API 包装器
COPY mmore_api.py /app/mmore_api.py

ENV PYTHONPATH="/app/mmore_repo/src:/app"
ENV DASK_DISTRIBUTED__WORKER__DAEMON=False

EXPOSE 8002

CMD ["python3", "/app/mmore_api.py"]
