package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.FieldFill;
import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 在线人数采样表（用户数据看板）
 * 定时任务每 5 分钟写入一条，sample_time 截断到分钟且唯一。
 */
@Data
@TableName("stat_online_sample")
public class StatOnlineSample {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 采样时间（截断到分钟） */
    private LocalDateTime sampleTime;

    /** 当前在线总人数 */
    private Integer onlineCount;

    /** 其中学生数 */
    private Integer studentCount;

    /** 其中教师数 */
    private Integer teacherCount;

    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdAt;
}
