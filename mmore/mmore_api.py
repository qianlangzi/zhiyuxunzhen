"""MMORE FastAPI 服务
====================
将 MMORE 的 PDF 处理能力包装为 HTTP 微服务。

端点：
  POST /process    上传 PDF，返回提取的文本块 + 图片（base64）
  GET  /health     健康检查

流程：
  1. 接收 PDF 文件
  2. 保存到临时目录
  3. 调用 MMORE Dispatcher 处理 PDF（图文分离）
  4. 读取 merged_results.jsonl
  5. 返回 [{text, page, images: [base64...]}]

启动：
  uvicorn mmore_api:app --host 0.0.0.0 --port 8002
"""
import json
import os
import shutil
import tempfile
import base64
from pathlib import Path

from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse
import uvicorn

app = FastAPI(title="MMORE PDF Processor", version="1.0.0")

# MMORE 输出目录
OUTPUT_DIR = "/tmp/mmore_output"


@app.get("/health")
async def health():
    return {"status": "ok", "service": "mmore"}


@app.post("/process")
async def process_pdf(file: UploadFile = File(...)):
    """处理 PDF 文件，返回文本块 + 图片。

    返回格式：
    {
      "chunks": [
        {
          "text": "章节内容...",
          "page": 1,
          "images": ["base64编码的图片数据..."]
        }
      ],
      "total_pages": 200,
      "total_chunks": 365
    }
    """
    if not file.filename.lower().endswith(".pdf"):
        raise HTTPException(400, "只支持 PDF 文件")

    # 1. 保存上传的 PDF 到临时目录
    work_dir = tempfile.mkdtemp(prefix="mmore_work_")
    input_dir = os.path.join(work_dir, "input")
    output_dir = os.path.join(work_dir, "output")
    os.makedirs(input_dir, exist_ok=True)
    os.makedirs(output_dir, exist_ok=True)

    pdf_path = os.path.join(input_dir, file.filename)
    with open(pdf_path, "wb") as f:
        content = await file.read()
        f.write(content)

    try:
        # 2. 调用 MMORE process
        from mmore.process.crawler import Crawler, CrawlerConfig
        from mmore.process.dispatcher import Dispatcher, DispatcherConfig

        crawler_config = CrawlerConfig(
            root_dirs=[input_dir],
            supported_extensions=[".pdf"],
            output_path=output_dir,
        )
        crawler = Crawler(config=crawler_config)
        crawl_result = crawler.crawl()

        if not crawl_result:
            raise HTTPException(500, "MMORE 无法解析此 PDF")

        # Dispatcher 配置：使用 fast 模式（无需本地模型）
        dispatcher_config = DispatcherConfig(
            output_path=output_dir,
            mode="fast",  # fast 模式不依赖本地模型
        )
        dispatcher = Dispatcher(result=crawl_result, config=dispatcher_config)
        list(dispatcher())

        # 3. 合并结果
        processors_dir = os.path.join(output_dir, "processors")
        merged_file = os.path.join(output_dir, "merged", "merged_results.jsonl")
        os.makedirs(os.path.dirname(merged_file), exist_ok=True)

        all_chunks = []
        with open(merged_file, "w") as f:
            if os.path.isdir(processors_dir):
                for proc_name in sorted(os.listdir(processors_dir)):
                    results_path = os.path.join(processors_dir, proc_name, "results.jsonl")
                    if os.path.exists(results_path):
                        with open(results_path) as pf:
                            for line in pf:
                                stripped = line.strip()
                                if stripped:
                                    f.write(stripped + "\n")

        # 4. 读取并解析结果
        if not os.path.exists(merged_file):
            raise HTTPException(500, "MMORE 处理结果为空")

        with open(merged_file) as f:
            for line in f:
                if not line.strip():
                    continue
                doc = json.loads(line)
                # MMORE 输出格式：{md_type, file_name, file_path, content, modalities}
                content = doc.get("content", {})
                text = content.get("text", "") if isinstance(content, dict) else str(content)

                # 提取图片（modalities 中的 image 类型）
                images = []
                modalities = doc.get("modalities", [])
                for mod in modalities:
                    if mod.get("type") == "image":
                        img_path = mod.get("path", "")
                        if img_path and os.path.exists(img_path):
                            with open(img_path, "rb") as img_file:
                                b64 = base64.b64encode(img_file.read()).decode("utf-8")
                                images.append(b64)

                # 页码：从 metadata 中获取，或默认 0
                page = doc.get("metadata", {}).get("page", 0)

                if text.strip():
                    all_chunks.append({
                        "text": text.strip(),
                        "page": page,
                        "images": images,
                    })

        # 5. 清理临时目录
        shutil.rmtree(work_dir, ignore_errors=True)

        return JSONResponse({
            "chunks": all_chunks,
            "total_chunks": len(all_chunks),
            "filename": file.filename,
        })

    except HTTPException:
        raise
    except Exception as e:
        shutil.rmtree(work_dir, ignore_errors=True)
        raise HTTPException(500, f"MMORE 处理失败: {type(e).__name__}: {str(e)}")


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8002)
