package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

/**
 * 管理端-人数总览（人数管理顶部指标卡）
 */
@Data
@Builder
public class AdminUserStatsVO {

    /** 用户总数（不含逻辑删除） */
    private Long totalUsers;

    private Long studentCount;
    private Long teacherCount;
    private Long teachingSecretaryCount;
    private Long deptHeadCount;
    private Long adminCount;
    private Long opsCount;
    private Long auditorCount;

    /** 冻结账号数（status=1） */
    private Long frozenCount;

    /** 待审核教师数（auditStatus=1） */
    private Long pendingTeacherCount;

    /** 今日新注册数 */
    private Long todayNewUsers;

    /** 近 7 天新注册数 */
    private Long weekNewUsers;
}
