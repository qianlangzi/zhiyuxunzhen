"""安全策略集中管理（PRD 10）

安全策略不是可以被模型覆盖的 Prompt，而是模型调用前后的代码规则。
- 输入检查：阻断自伤/他伤/制毒等高危内容
- 输出检查：检测是否泄露 system prompt、隐藏疾病等
- 所有规则版本可审计
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field

from app.domain.enums import SafetyAction


# 高危关键词（阻断）
_BLOCK_KEYWORDS: tuple[str, ...] = (
    "自杀", "自残", "杀", "毒品", "制毒", "配方",
    "怎么自杀", "如何自杀", "安乐死方法",
)

# 处方/真实诊疗相关（转为教学免责声明）
_DEFLECT_KEYWORDS: tuple[str, ...] = (
    "处方", "开药", "用量", "剂量", "用药剂量", "药物剂量", "怎么吃药",
    "真实患者", "真实病人",
)

# 系统提示词泄露特征
# 注意：hidden_disease / standard_path / 病例配置 是「病例配置类」输出的正常业务字段名
# （case draft / 质检 / 练习题 的输出本就包含这些字段），不是系统提示词泄露特征，
# 故不得纳入本清单，否则会误拦截所有病例生成功能（历史 bug：OUTPUT_SCHEMA_INVALID）。
_PROMPT_LEAK_PATTERNS: tuple[re.Pattern[str], ...] = (
    re.compile(r"system\s*prompt", re.IGNORECASE),
    re.compile(r"你的指令", re.IGNORECASE),
    re.compile(r"你的提示词", re.IGNORECASE),
)

# 隐藏疾病泄露特征
_HIDDEN_DISEASE_HINTS: tuple[str, ...] = (
    "隐藏疾病", "hiddenDisease", "hidden_disease",
    "标准诊断", "标准答案", "正确诊断",
)


@dataclass
class SafetyDecision:
    """安全策略决策结果"""

    action: SafetyAction
    reason: str = ""
    matched_keywords: list[str] = field(default_factory=list)

    @property
    def is_blocked(self) -> bool:
        return self.action == SafetyAction.BLOCK

    @property
    def is_deflect(self) -> bool:
        return self.action == SafetyAction.DEFLECT

    @property
    def is_allowed(self) -> bool:
        return self.action == SafetyAction.ALLOW


class SafetyPolicy:
    """安全策略

    不可被模型覆盖的代码规则。
    在模型调用前后执行，确保即使模型行为异常也能拦截。
    """

    def check_input(self, text: str, *, is_sp_case: bool = False,
                    learning_mode: bool = False) -> SafetyDecision:
        """检查学生输入是否安全

        - 自伤/他伤/制毒 -> BLOCK（任何场景一律拦截）
        - 处方/剂量 -> DEFLECT（转为教学免责声明）
          - 例外 1：SP 模拟病例问诊（is_sp_case=True）本就是训练学生开药/手术/输液等
            诊疗流程的场景，此时不拦截这类话术，让学生能正常练习
          - 例外 2：学伴等"学习陪伴"场景（learning_mode=True）——学生问"怎么吃药/
            剂量"通常是学习提问而非真实诊疗，也不拦截，转为正常教学回答
        - 其他 -> ALLOW
        """
        if not text or not text.strip():
            return SafetyDecision(action=SafetyAction.ALLOW)

        text_lower = text.lower()

        # 检查阻断关键词（高危内容不受任何场景豁免）
        blocked = [kw for kw in _BLOCK_KEYWORDS if kw in text_lower]
        if blocked:
            return SafetyDecision(
                action=SafetyAction.BLOCK,
                reason="检测到高危敏感内容",
                matched_keywords=blocked,
            )

        # 检查转教学免责声明关键词（SP 病例问诊 / 学伴学习场景豁免）
        if not is_sp_case and not learning_mode:
            deflected = [kw for kw in _DEFLECT_KEYWORDS if kw in text_lower]
            if deflected:
                return SafetyDecision(
                    action=SafetyAction.DEFLECT,
                    reason="涉及真实诊疗/处方，转为教学免责声明",
                    matched_keywords=deflected,
                )

        return SafetyDecision(action=SafetyAction.ALLOW)

    def check_output(
        self,
        text: str,
        *,
        hidden_disease: str | None = None,
        allow_clinical: bool = False,
    ) -> SafetyDecision:
        """检查模型输出是否安全

        - 泄露 system prompt -> BLOCK
        - 泄露隐藏疾病 -> BLOCK
        - 包含真实处方/剂量 -> DEFLECT（SP 病例问诊场景豁免）
        - 其他 -> ALLOW
        """
        if not text or not text.strip():
            return SafetyDecision(action=SafetyAction.ALLOW)

        # 检查系统提示词泄露
        for pattern in _PROMPT_LEAK_PATTERNS:
            if pattern.search(text):
                return SafetyDecision(
                    action=SafetyAction.BLOCK,
                    reason="模型输出疑似泄露系统提示词或病例配置",
                    matched_keywords=[pattern.pattern],
                )

        # 检查隐藏疾病泄露
        if hidden_disease and len(hidden_disease) > 2:
            # 检查泄露特征词
            for hint in _HIDDEN_DISEASE_HINTS:
                if hint in text:
                    return SafetyDecision(
                        action=SafetyAction.BLOCK,
                        reason="模型输出疑似泄露隐藏疾病信息",
                        matched_keywords=[hint],
                    )
            # 检查直接包含隐藏疾病值
            if hidden_disease in text:
                return SafetyDecision(
                    action=SafetyAction.BLOCK,
                    reason="模型输出疑似直接泄露隐藏诊断",
                    matched_keywords=[hidden_disease],
                )

        # 检查处方/剂量（SP 病例诊疗场景豁免）
        if not allow_clinical:
            text_lower = text.lower()
            deflected = [kw for kw in _DEFLECT_KEYWORDS if kw in text_lower]
            if deflected:
                return SafetyDecision(
                    action=SafetyAction.DEFLECT,
                    reason="模型输出包含处方/剂量相关内容",
                    matched_keywords=deflected,
                )

        return SafetyDecision(action=SafetyAction.ALLOW)


# 全局单例
safety_policy = SafetyPolicy()
