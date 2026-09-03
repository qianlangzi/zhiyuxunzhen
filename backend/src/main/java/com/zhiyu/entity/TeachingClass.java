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

    /** 创建/归属教师ID（管理员预置为 null），教师自建班级时落该字段 */
    private Long teacherId;

    /** 学生加入班级的邀请码（教师自建班级唯一；管理员预置为 null） */
    private String inviteCode;

    /** 班级手动排序权重（0=未排序，数值越小越靠前） */
    private Integer sortOrder;

    private Integer status;
    private Integer isDeleted;
}
