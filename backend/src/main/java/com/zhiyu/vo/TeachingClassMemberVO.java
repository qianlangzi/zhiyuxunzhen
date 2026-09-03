package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

/**
 * 班级成员（学生）
 */
@Data
@Builder
public class TeachingClassMemberVO {
    private Long studentId;
    private String username;
    private String realName;
    private String schoolName;
    private String grade;
    private String className;
}