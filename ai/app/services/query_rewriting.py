"""查询改写服务（Query Rewriting）

检索前把用户原始提问改写为更适合向量检索的查询：
  1. 口语→医学术语规范化（"心慌得厉害" → "心悸 心律失常"）
  2. 多轮对话指代消解（"那它怎么治？" → "心房颤动的治疗"）
  3. 剥离闲聊/礼貌用语，保留检索意图

设计原则：
  - 需要 LLM（DeepSeek 等 OpenAI 兼容服务）；未配置/调用失败时静默返回原 query
  - 轻量调用：max_tokens 120、temperature 0，延迟约 300-800ms
  - 改写失败绝不能阻断检索
"""
import asyncio
import hashlib
from collections import OrderedDict

from app.core.config import settings
from app.core.logging import get_logger, log_event
from logging import INFO, WARNING

logger = get_logger(__name__)

_REWRITE_SYSTEM_PROMPT = (
    "你是医学教材检索的查询改写器。把用户的口语化提问改写为适合向量检索的医学术语查询。\n"
    "规则：\n"
    "1. 口语转规范医学术语（如：心慌→心悸；拉肚子→腹泻；发烧→发热）\n"
    "2. 如提供了对话历史，先消解指代（它/这个/那种病→具体实体）再改写\n"
    "3. 去掉寒暄、语气词，只保留检索意图\n"
    "4. 保留疾病/症状/检查/治疗等关键实体，可补充 1-3 个紧密相关的同义术语\n"
    "5. 只输出一行改写后的查询，不要解释、不要标点列表"
)

# 不改写的短query类型：纯术语拼接（teacher 模块程序生成的 query）
_MIN_REWRITE_LEN = 6

# LRU 缓存：相同 query + 相同近 4 轮历史 → 复用改写结果，省一次 LLM 调用（300-800ms）。
# 程序化 query（teacher 模块、search_textbook 工具）无历史上下文，命中率最高。
_CACHE_MAX = 256
_REWRITE_CACHE: OrderedDict[str, str] = OrderedDict()


def _cache_key(query: str, history: list[dict[str, str]] | None) -> str:
    recent = (history or [])[-4:]
    h = "|".join(f"{m.get('role', '')}:{m.get('content', '')[:80]}" for m in recent)
    return f"{query}#{hashlib.md5(h.encode('utf-8')).hexdigest()}"


def _cache_put(key: str, value: str) -> None:
    _REWRITE_CACHE[key] = value
    _REWRITE_CACHE.move_to_end(key)
    while len(_REWRITE_CACHE) > _CACHE_MAX:
        _REWRITE_CACHE.popitem(last=False)


async def rewrite_query(
    query: str,
    history: list[dict[str, str]] | None = None,
    trace_id: str = "-",
) -> str:
    """改写检索查询；未配置 LLM / 失败 / query 已规范时返回原 query。"""
    query = query.strip()
    if (
        not settings.query_rewrite_enabled
        or not query
        or len(query) < _MIN_REWRITE_LEN
    ):
        return query

    # LRU 命中：直接复用（含"判断过无需改写"的负缓存，避免重复调 LLM）
    key = _cache_key(query, history)
    if key in _REWRITE_CACHE:
        _REWRITE_CACHE.move_to_end(key)
        return _REWRITE_CACHE[key]

    from app.services.llm_client import llm_client

    # LLM 未配置时 llm_client.chat 会返回降级文案，不能用于检索——直接跳过
    if not llm_client.available:
        return query

    # 最近 4 轮历史足够消解指代，控制 prompt 体积
    recent = (history or [])[-4:]
    history_text = "\n".join(f"{m['role']}: {m['content'][:120]}" for m in recent)

    messages = [
        {"role": "system", "content": _REWRITE_SYSTEM_PROMPT},
        {"role": "user", "content": (f"对话历史：\n{history_text}\n\n" if history_text else "")
            + f"当前提问：{query}"},
    ]
    try:
        rewritten = await asyncio.wait_for(
            llm_client.chat(
                messages, temperature=0.0, max_tokens=120, trace_id=trace_id,
            ),
            timeout=5.0,
        )
    except Exception as e:  # noqa: BLE001 - 改写失败绝不阻断检索，且不缓存失败结果
        log_event(logger, WARNING, "query_rewrite_error",
                  trace_id=trace_id, error=type(e).__name__)
        return query

    rewritten = rewritten.strip().strip("\"'“”").split("\n")[0].strip()
    # 兜底：改写结果异常（过短/过长/为空）时回退原 query
    if not rewritten or len(rewritten) < 3 or len(rewritten) > 200:
        _cache_put(key, query)  # 负缓存：此 query 无有效改写，下次不再调 LLM
        return query

    _cache_put(key, rewritten)
    if rewritten != query:
        log_event(logger, INFO, "query_rewritten",
                  trace_id=trace_id, original=query[:50], rewritten=rewritten[:80])
    return rewritten
