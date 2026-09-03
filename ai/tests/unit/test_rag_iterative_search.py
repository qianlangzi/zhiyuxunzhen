"""自适应迭代检索回归测试。

锁定修复：rewrite=True（生产主路径）时迭代检索必须触发
（原先 retry_query 恒等于 effective_query 导致永不触发）。
"""
import sys

import pytest

sys.path.insert(0, ".")

from app.core.config import settings
from app.services.rag_service import rag_service


def _hit(id_: str, score: float) -> dict:
    return {"id": id_, "book_name": "《内科学》", "chunk_text": f"c{id_}",
            "chapter": "x", "page_number": 1, "score": score}


@pytest.mark.asyncio
async def test_iterative_triggers_with_rewrite_and_retries_original(monkeypatch):
    """rewrite=True：首轮用改写 R 命中低分 → 应补一轮原始 query 并融合。"""
    queries = []
    first = [{"ts": True, **hit} for hit in [_hit("a", 0.30)]]

    async def fake_search_once(q, top_k=-1, trace_id="-", *a, **k):
        queries.append(q)
        if len(queries) == 1:  # 第一轮：改写后 query，输出低分
            return [h.copy() for h in first], 0.30
        return [_hit("b", 0.99)], 0.95  # 第二轮：原始 query，输出高分新命

    async def fake_rewrite(query, history=None, trace_id="-"):
        return "心房颤动的治疗原则"  # 固定改写结果，与原始 query 不同

    monkeypatch.setattr(settings, "iterative_search_enabled", True)
    monkeypatch.setattr(settings, "iterative_score_threshold", 0.45)
    monkeypatch.setattr(rag_service, "_search_once", fake_search_once)
    monkeypatch.setattr(
        "app.services.query_rewriting.rewrite_query", fake_rewrite,
    )

    cits = await rag_service.search(
        "房颤怎么治", top_k=5, trace_id="t1", strategy="dense", rewrite=True,
    )

    # 重查确实发生，且第二轮用的是原始 query（而非改写后 R）
    assert len(queries) == 2
    assert queries[0] == "心房颤动的治疗原则"
    assert queries[1] == "房颤怎么治"
    # 融合后带上了第二轮的高分新命
    ids = {c.chunk_text for c in cits}
    assert "cb" in ids and "ca" in ids


@pytest.mark.asyncio
async def test_iterative_without_rewrite_retries_rewritten(monkeypatch):
    """rewrite=False：首轮用原句低分 → 改写后补一轮并融合。"""
    queries = []
    n = {"i": 0}

    async def fake_search_once(q, top_k=-1, trace_id="-", *a, **k):
        queries.append(q)
        n["i"] += 1
        if n["i"] == 1:
            return [_hit("x", 0.30)], 0.30
        return [_hit("y", 0.99)], 0.95

    async def fake_rewrite(query, history=None, trace_id="-"):
        return "心电图波形紊乱如何治疗"

    monkeypatch.setattr(settings, "iterative_search_enabled", True)
    monkeypatch.setattr(settings, "iterative_score_threshold", 0.45)
    monkeypatch.setattr(rag_service, "_search_once", fake_search_once)
    monkeypatch.setattr(
        "app.services.query_rewriting.rewrite_query", fake_rewrite,
    )

    await rag_service.search(
        "心电图的波乱糟糟的怎么治", top_k=5, trace_id="t2",
        strategy="dense", rewrite=False,
    )
    assert len(queries) == 2
    assert queries[0] == "心电图的波乱糟糟的怎么治"
    assert queries[1] == "心电图波形紊乱如何治疗"