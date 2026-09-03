package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

/**
 * 学生端某个班级的详情（闭环内容）：班级信息 + 教师信息 + 老师分享的资料 + 该班作业
 */
@Data
@Builder
public class StudentClassDetailVO {
    private Long classId;
    private String name;
    private String grade;
    private Integer status;
    private Long teacherId;
    private String teacherName;
    private String teacherSchool;
    private Long studentCount;
    private LocalDateTime joinedAt;
    /** 老师分享到该班级的资料（备课发布），每项含 lessonId/lessonTitle/materials 等 */
    private List<Map<String, Object>> materials;
    /** 该班级的作业（含我的实例状态） */
    private List<Map<String, Object>> assignments;
}