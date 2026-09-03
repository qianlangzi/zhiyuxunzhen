package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

/**
 * 学生启动问诊会话请求（PRD 5.2 第 1 步）
 * 学生选择病例进入问诊室，Spring Boot 侧创建 ChatSession，FastAI 通过 SSE 处理问诊流
 */
@Data
public class SessionStartDTO {

    @NotNull(message = "病例ID不能为空")
    private Long caseId;

    /** 作业实例ID（可选，每日一例/自主训练时为空） */
    private Long assignmentInstanceId;

    /** 组合包:病例任务项进度ID（可选，存量作业/自主训练时为空） */
    private Long assignmentItemProgressId;
}
