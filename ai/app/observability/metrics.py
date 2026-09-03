"""轻量指标接口，避免业务模块自行创建不一致的指标名。"""
from collections import Counter


_COUNTERS: Counter[str] = Counter()


def increment(name: str, value: int = 1) -> None:
    _COUNTERS[name] += value


def snapshot() -> dict[str, int]:
    return dict(_COUNTERS)
