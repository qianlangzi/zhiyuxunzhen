package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class TeachingClassVO {
    private Long id;
    private String name;
    private String grade;
    private Long studentCount;
}
