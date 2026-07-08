package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

/**
 * 全局驾驶舱聚合指标（PRD 4.13）
 */
@Data
@Builder
public class DashboardVO {

    /** 今日活跃学生数 */
    private Long todayActiveStudents;

    /** 活跃教师数（已认证） */
    private Long activeTeachers;

    /** 问诊会话总数 */
    private Long chatSessionCount;

    /** 作业提交数 */
    private Long assignmentSubmitCount;

    /** 待审核病例数 */
    private Long pendingCaseAuditCount;

    /** 待审核教师数 */
    private Long pendingTeacherAuditCount;

    /** 官方认证病例数 */
    private Long officialCaseCount;
}
