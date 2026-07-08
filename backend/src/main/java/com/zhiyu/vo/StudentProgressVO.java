package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 作业进度学生明细（PRD 4.3）
 */
@Data
@Builder
public class StudentProgressVO {
    private Long instanceId;
    private Long studentId;
    private String studentName;
    /** 0未开始 1问诊中 2格式打回 3AI批阅中 4待复核 5已完成 */
    private Integer status;
    private LocalDateTime submitTime;
}
