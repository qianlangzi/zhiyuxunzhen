package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 学生端「我的课程」班级卡（学习通式课程列表项）
 */
@Data
@Builder
public class MyClassVO {
    private Long id;
    private String name;
    private String grade;
    private Integer status;
    private Long teacherId;
    private String teacherName;
    private Long studentCount;
    private LocalDateTime joinedAt;

    /** 该班我的未完成作业数（作业实例状态 0/1/2），与待办页口径一致 */
    private Long pendingAssignmentCount;

    /** 该班我的未完成资料任务数（materialOnly=1 且未标记完成） */
    private Long pendingLessonCount;
}