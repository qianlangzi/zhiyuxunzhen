package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.FieldFill;
import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import java.time.LocalDateTime;

/**
 * 学生资料任务完成进度（V45）
 * 学生 × 备课发布 唯一；materialOnly=1 的资料任务完成后从待办清除。
 */
@Data
@TableName("lesson_task_progress")
public class LessonTaskProgress {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long publishId;
    private Long studentId;
    /** 0未完成 1已完成 */
    private Integer status;
    private LocalDateTime completedAt;
    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdAt;
    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;
}
