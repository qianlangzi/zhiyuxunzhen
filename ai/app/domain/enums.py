"""领域枚举定义

禁止业务代码使用随意字符串，所有状态和类型都使用枚举。
"""
from enum import Enum


class Role(str, Enum):
    """用户角色"""
    STUDENT = "student"
    TEACHER = "teacher"
    ADMIN = "admin"
    OPERATOR = "operator"


class SessionStatus(str, Enum):
    """问诊会话状态"""
    ACTIVE = "ACTIVE"
    ARCHIVED = "ARCHIVED"
    ENDED = "ENDED"


class TaskStatus(str, Enum):
    """异步任务状态"""
    PENDING = "PENDING"
    RUNNING = "RUNNING"
    SUCCEEDED = "SUCCEEDED"
    FAILED_RETRYABLE = "FAILED_RETRYABLE"
    FAILED_FINAL = "FAILED_FINAL"
    CANCELLED = "CANCELLED"


class SafetyAction(str, Enum):
    """安全策略处理动作"""
    ALLOW = "ALLOW"
    BLOCK = "BLOCK"
    WARN = "WARN"
    DEFLECT = "DEFLECT"  # 转为教学免责声明


class EvidenceQuality(str, Enum):
    """证据质量等级"""
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"
    INSUFFICIENT = "INSUFFICIENT"


class ReviewSource(str, Enum):
    """批阅结果来源"""
    AI = "AI"
    AI_ASSISTED = "AI_ASSISTED"  # AI 辅助，非正式成绩
    TEACHER = "TEACHER"
    RULE = "RULE"  # 纯规则判题


class TaskType(str, Enum):
    """异步任务类型"""
    REVIEW = "review"
    KNOWLEDGE_INGEST = "knowledge_ingest"
    PAPER = "paper"          # 新增：AI 组卷异步任务


class ModelTaskType(str, Enum):
    """模型调用任务类型（用于按任务选择模型配置）"""
    SP_CHAT = "sp_chat"
    STRUCTURED_EXTRACT = "structured_extract"
    REVIEW = "review"
    VISION = "vision"
    EMBEDDING = "embedding"
    MENTOR_EXTRACT = "mentor_extract"
    EVALUATOR_EXTRACT = "evaluator_extract"
    SAFETY_CLASSIFY = "safety_classify"
