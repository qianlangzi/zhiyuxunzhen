# -*- coding: utf-8 -*-
"""小批量检索抽验：对 Milvus 里的 OpenCMKG 新增知识做 top-N 向量检索。"""
import json
import sys
import urllib.request

from pymilvus import MilvusClient

sys.path.insert(0, r"e:\zhiyu\datasets")
import import_opencmkg_knowledge as I  # 复用 embed_one / 常量

QUERIES = ["高血压该挂什么科，有哪些症状，平时吃什么药", "糖尿病常见症状和处理方式", "感冒需要做什么检查"]


def main():
    cli = MilvusClient(uri=I.MILVUS_URI)
    for q in QUERIES:
        vec = I.embed_one(q)
        hits = cli.search(
            collection_name=I.MILVUS_COLLECTION,
            data=[vec],
            limit=3,
            output_fields=["chunk_text", "book_name", "chapter", "subject"],
            search_params={"metric_type": "COSINE", "params": {"level": 1}},
        )[0]
        print(f"\nQ: {q}\n  Top-3:")
        for r in hits:
            ent = r["entity"]
            print(f"  [{r['distance']:.3f}] <{ent['book_name']}> {ent['subject']}/{ent['chapter']}")
            print(f"      {ent['chunk_text'][:80]}")


if __name__ == "__main__":
    main()