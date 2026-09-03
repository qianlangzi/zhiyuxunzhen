package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

/**
 * 用户数据看板总览（PRD 4.13 扩展）
 */
@Data
@Builder
public class UserOverviewVO {

    /** 注册账号总数（未删除） */
    private Long totalUsers;

    /** 其中学生数 */
    private Long studentCount;

    /** 其中教师数 */
    private Long teacherCount;

    /** 今日新增注册数 */
    private Long todayNewUsers;

    /** 今日活跃用户数（今日有登录） */
    private Long todayActiveUsers;

    /** 当前在线人数（5 分钟活跃窗口） */
    private Long currentOnline;

    /** 当前在线学生数 */
    private Long currentOnlineStudents;

    /** 当前在线教师数 */
    private Long currentOnlineTeachers;

    /** 今日峰值在线人数 */
    private Integer todayPeakOnline;

    /** 昨日峰值在线人数 */
    private Integer yesterdayPeakOnline;

    /** 昨日活跃用户数 */
    private Long yesterdayActiveUsers;
}
