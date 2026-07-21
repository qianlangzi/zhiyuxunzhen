package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName("assignment_target_class")
public class AssignmentTargetClass extends BaseEntity {
    private Long assignmentId;
    private Long classId;
}
