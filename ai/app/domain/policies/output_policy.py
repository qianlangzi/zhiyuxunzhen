"""SP Agent 输出校验策略（设计文档 6.2）

模型输出在发送给学生前必须通过这些校验：
1. 是否泄露隐藏疾病或标准答案
2. 是否出现处方/剂量/真实临床诊疗承诺
3. 是否包含不该出现在患者口中的医学术语
4. 是否超过长度限制
5. 是否为空或过短

校验失败的回复不会直接发给学生，而是返回安全拒答或触发重新生成。
"""
from __future__ import annotations

from dataclasses import dataclass, field

from app.domain.policies.safety_policy import safety_policy


@dataclass
class OutputCheckResult:
    """输出校验结果"""

    passed: bool
    reason: str = ""
    action: str = "ALLOW"  # ALLOW / BLOCK / REGENERATE
    suggestions: list[str] = field(default_factory=list)


class OutputPolicy:
    """SP Agent 输出校验策略

    在 SP Agent 生成回复后、发送给学生前执行。
    """

    MAX_REPLY_LENGTH = 500  # 单次回复最大字符数
    MIN_REPLY_LENGTH = 1    # 单次回复最小字符数

    # 患者通常不会主动使用的医学术语
    _MEDICAL_TERMS: tuple[str, ...] = (
        "鉴别诊断", "辅助检查", "主诉", "现病史",
        "既往史", "家族史", "过敏史",
        "心肌酶", "血常规", "肝功能", "肾功能",
        "心电图提示", "CT提示", "MRI提示",
        "初步诊断", "临床诊断",
    )

    def validate_sp_reply(
        self,
        reply: str,
        *,
        hidden_disease: str | None = None,
    ) -> OutputCheckResult:
        """校验 SP 回复

        Args:
            reply: SP Agent 生成的回复文本
            hidden_disease: 病例配置的隐藏疾病（用于检查泄露）

        Returns:
            OutputCheckResult: 校验结果
        """
        if not reply or not reply.strip():
            return OutputCheckResult(
                passed=False,
                reason="回复为空",
                action="REGENERATE",
                suggestions=["请生成非空回复"],
            )

        # 1. 长度检查
        if len(reply) > self.MAX_REPLY_LENGTH:
            return OutputCheckResult(
                passed=False,
                reason=f"回复超过最大长度 {self.MAX_REPLY_LENGTH} 字（当前 {len(reply)} 字）",
                action="REGENERATE",
                suggestions=[f"请将回复压缩到 {self.MAX_REPLY_LENGTH} 字以内"],
            )

        # 2. 安全策略检查（复用 SafetyPolicy）
        safety = safety_policy.check_output(reply, hidden_disease=hidden_disease)
        if safety.is_blocked:
            return OutputCheckResult(
                passed=False,
                reason=safety.reason,
                action="BLOCK",
                suggestions=["返回安全拒答文案"],
            )

        # 3. 检查是否包含医学术语（SP 应该用患者语言）
        medical_terms = self._check_medical_terminology(reply)
        if medical_terms:
            return OutputCheckResult(
                passed=False,
                reason="回复包含医学术语，不符合患者身份",
                action="REGENERATE",
                suggestions=[f"请用患者日常语言替换: {', '.join(medical_terms)}"],
            )

        return OutputCheckResult(passed=True)

    def _check_medical_terminology(self, text: str) -> list[str]:
        """检查回复是否包含不该出现在患者口中的医学术语"""
        return [term for term in self._MEDICAL_TERMS if term in text]


# 全局单例
output_policy = OutputPolicy()
