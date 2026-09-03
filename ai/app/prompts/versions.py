"""发布中的 Prompt 版本清单；业务代码只引用这里的稳定名称。"""

PROMPT_VERSIONS: dict[str, str] = {
    "sp": "sp.v1",
    "mentor": "mentor.v1",
    "reviewer": "reviewer.v1",
    "evaluator": "evaluator.v1",
    "daily_case": "daily_case.v1",
    "report": "report.v1",
    "learning_path": "learning_path.v1",
}


def prompt_version(name: str) -> str:
    try:
        return PROMPT_VERSIONS[name]
    except KeyError as exc:
        raise ValueError(f"unknown prompt: {name}") from exc
