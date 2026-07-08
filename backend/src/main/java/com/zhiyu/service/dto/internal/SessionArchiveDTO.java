package com.zhiyu.service.dto.internal;

import lombok.Data;

/**
 * 问诊会话归档回调（PRD 9.4）
 * FastAPI 完成问诊评分后回调 Spring Boot 归档会话
 */
@Data
public class SessionArchiveDTO {

    private Long sessionId;

    /** 四维评分 JSON */
    private String osceScoreJson;

    /** 最终报告 */
    private String finalReport;

    /** 最终思维树 JSON */
    private String reasoningTreeJson;
}
