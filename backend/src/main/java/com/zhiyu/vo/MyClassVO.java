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
}