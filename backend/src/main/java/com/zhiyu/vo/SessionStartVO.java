package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 学生启动问诊会话响应（PRD 5.2 第 1 步）
 */
@Data
@Builder
public class SessionStartVO {

    private Long sessionId;

    private Long studentId;

    private Long caseId;

    private Long assignmentInstanceId;

    /** 组合包:病例任务项进度ID(自主训练/存量为空) */
    private Long assignmentItemProgressId;

    /** 初始检查费用 = 0 */
    private BigDecimal totalExamCost;

    /** 0进行中 1已完成 2异常中断 */
    private Integer status;

    private LocalDateTime createdAt;

    /**
     * SP 主动开场白（PRD 5.2 优化·P2-1 进阶）。
     * 学生首次进入会话时，AI 中台按病例上下文生成 1~2 句病人口吻自然开场；
     * 移动端据此在首屏填充 patient 流式气泡，无需等待学生先说话。
     * 字段为空表示 AI 不可用（已在前端用「医生您好」兜底）。
     */
    private String openingMessage;

    /** AI 不可用或降级时为 true，移动端据此决定是否展示「重新生成」按钮 */
    private Boolean openingDegraded;

    /** true=复用了该病例进行中的历史会话（续聊上次记录）；false=新建会话 */
    private Boolean resumed;

    /** 问诊室展示标题（科室+病号，如「心血管内科 · No.213」），不暴露具体病名 */
    private String caseTitle;

    /** 所属科室 */
    private String department;

    /** 病号=题号 */
    private String caseNo;
}
