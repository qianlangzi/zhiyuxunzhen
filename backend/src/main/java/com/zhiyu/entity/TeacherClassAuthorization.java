package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName("teacher_class_authorization")
public class TeacherClassAuthorization extends BaseEntity {
    private Long teacherId;
    private Long classId;
}
