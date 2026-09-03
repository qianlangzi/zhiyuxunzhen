package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class TeachingClassVO {
    private Long id;
    private String name;
    private String grade;
    private Integer status;
    private Long teacherId;
    private String inviteCode;
    private Long studentCount;
}
