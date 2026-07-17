"""通用响应与溯源结构"""
from typing import Any

from pydantic import BaseModel, Field


class R(BaseModel):
    """统一响应包装，与 Spring Boot R<T> 对齐（code=0 成功）"""

    code: int = 0
    message: str = "success"
    data: Any | None = None


class Citation(BaseModel):
    """RAG 溯源（PRD 7.3.2）"""

    book_name: str = Field(description="教材书名")
    edition: str | None = Field(default=None, description="版本")
    chapter: str | None = Field(default=None, description="章节")
    page_number: int | None = Field(default=None, description="页码")
    chunk_text: str | None = Field(default=None, description="命中的原文片段")


class ReasoningTreeNode(BaseModel):
    """思维决策树节点（PRD 4.7.2）"""

    id: str
    type: str = Field(description="symptom/history/exam/diagnosis/cost")
    label: str
    status: str = Field(description="queried/queried_missing/exam_ordered/exam_overuse/excluded/excluded_wrong/missing_high_risk/normal/warning/overrun")
    cost: float | None = Field(default=None, description="检查费用，仅 exam/cost 节点")
    evidence: str | None = Field(default=None, description="证据说明")


class ReasoningTreeEdge(BaseModel):
    """思维树边"""

    from_id: str = Field(alias="from")
    to_id: str = Field(alias="to")
    relation: str = Field(default="related", description="related/leads_to/excludes")

    model_config = {"populate_by_name": True}


class ReasoningTree(BaseModel):
    """完整思维树"""

    nodes: list[ReasoningTreeNode] = []
    edges: list[ReasoningTreeEdge] = []
