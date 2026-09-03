# -*- coding: utf-8 -*-
"""用例级 RAG 端到端验证：真实 rag_service.(hybrid检索+rewrite) -> LLM grounded 回答。

目标：确认扩充的 OpenCMKG 向量知识能否被"生成侧"真正采纳进回答。
运行位置：e:\\zhiyu\\ai（保证可 import app.*）
用法：python e2e_rag_check.py
"""
import asyncio

from app.core.config import settings
from app.services.rag_service import rag_service
from app.services.llm_client import llm_client

CASES = [
    "高血压该挂什么科，主要有哪些症状，平时吃什么药？",
    "糖尿病患者常见症状和一般处理方式是什么？",
    "感冒一般需要做哪些检查？",
]

SYSTEM = (
    "你是一名严谨的内科医学助手。请严格依据下方【检索资料】作答，"
    "不要编造检索资料之外的事实。若资料不足，请明确说明。回答要分条目、简洁、面向医学生。"
)


def cite_block(citations) -> str:
    lines = []
    for i, c in enumerate(citations, 1):
        src = c.book_name or "无"
        topic = c.chapter or "-"
        lines.append(f"[{i}] 《{src}》/章节:{topic}\n{c.chunk_text[:220]}")
    return "\n\n".join(lines)


async def run_one(q: str, idx: int, strategy: str) -> None:
    print(f"\n{'='*70}\n用例 {idx} [{strategy}]: {q}")
    # 生产主路径：rewrite 口语→术语；strategy 显式传入（hybrid / rerank 对比）
    citations = await rag_service.search(q, rewrite=True, strategy=strategy, trace_id="e2e")
    if not citations:
        print("  [结果] 未检索到内容")
        return

    books = {}
    for c in citations:
        books[c.book_name or "无"] = books.get(c.book_name or "无", 0) + 1
    print(f"  检索命中 {len(citations)} 条，来源分布: {books}")
    kg = books.get("中文医学知识图谱(OpenCMKG)", 0)
    print(f"  OpenCMKG 被检索采纳: {'是' if kg else '否'}（{kg} 条）")

    if not settings.llm_configured:
        print("  [跳过生成] LLM 未配置")
        return

    prompt = (
        f"问题：{q}\n\n"
        f"【检索资料】\n{cite_block(citations[:5])}\n\n"
        "请给出条目化回答，并在每个要点后标注对应的资料编号，如〔1〕〔3〕。"
    )
    answer = await llm_client.chat(
        [{"role": "system", "content": SYSTEM}, {"role": "user", "content": prompt}],
        trace_id="e2e",
    )
    print(f"  [回答]\n{answer}")


async def main() -> None:
    print("RAG 配置: strategy=%s top_k=%s iterative=%s llm=%s" % (
        settings.rag_strategy, settings.rag_top_k,
        settings.iterative_search_enabled, settings.llm_model,
    ))
    strategies = list(dict.fromkeys([settings.rag_strategy, "rerank"]))
    for i, q in enumerate(CASES, 1):
        for s in strategies:
            try:
                await run_one(q, i, s)
            except Exception as e:  # noqa: BLE001
                print(f"  用例{i}[{s}] 出错: {e!r}")


if __name__ == "__main__":
    asyncio.run(main())