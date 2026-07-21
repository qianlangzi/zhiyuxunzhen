package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName("teaching_class")
public class TeachingClass extends BaseEntity {
    private String name;
    private String grade;
    private Integer status;
    private Integer isDeleted;
}
