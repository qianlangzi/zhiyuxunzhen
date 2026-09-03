package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@Builder
public class TeacherReviewQueueVO {
    private Long instanceId;
    /** 组合包:病例任务项进度ID(存量作业为NULL,批阅定位用) */
    private Long itemProgressId;
    /** 组合包:任务项ID */
    private Long itemId;
    /** 任务项类型：CASE=病例批阅 / PRACTICE=主观题批改 */
    private String itemType;
    /** 组合包:病例标题 */
    private String caseTitle;
    private Long assignmentId;
    private String assignmentTitle;
    /** 归属班级（作业可面向多个班级，取第一个作为分类维度） */
    private Long classId;
    private String className;
    private String studentName;
    private BigDecimal score;
    private String issue;
    /** 0未开始 1问诊中 2格式打回 3AI批阅中 4待复核 5已完成 */
    private Integer instanceStatus;
    private LocalDateTime submitTime;
    private Long latestReviewId;
}