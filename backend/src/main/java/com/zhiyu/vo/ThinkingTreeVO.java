package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.util.List;
import java.util.Map;

/**
 * 临床思维树 VO
 *
 * 字段对齐 ai/app/agents/mentor_agent.py 的输出 schema：
 * nodes / edges / socrates_hint，以及累计检查费用。
 */
@Data
@Builder
public class ThinkingTreeVO {
    private Long sessionId;
    /** 累计检查费用（元） */
    private Double totalExamCost;
    /** 思维树节点列表（结构：id/type/label/status/cost/evidence） */
    private List<Map<String, Object>> nodes;
    /** 思维树边列表（结构：from/to/relation） */
    private List<Map<String, Object>> edges;
    /** 苏格拉底式提示，可为 null */
    private String socraticPrompt;
    /** 当前问诊阶段：主诉采集/现病史/既往史/过敏史/家族史/个人史/查体/诊断 */
    private String currentStage;
}
