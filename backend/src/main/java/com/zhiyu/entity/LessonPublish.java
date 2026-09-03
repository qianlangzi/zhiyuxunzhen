package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.time.LocalDateTime;

/**
 * 备课发布记录
 * materialOnly=1 表示仅发资料（不绑定作业）；否则资料+病例+作业一起下发。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("lesson_publish")
public class LessonPublish extends BaseEntity {

    private Long lessonId;

    /** 关联作业 ID（materialOnly=0 时） */
    private Long assignmentId;

    private Long classId;

    /** 1仅发资料 0资料+病例+作业 */
    private Integer materialOnly;

    private LocalDateTime deadline;

    /** 0已发布 1已结束 */
    private Integer status;
}
