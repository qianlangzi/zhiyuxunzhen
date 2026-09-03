package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.FieldFill;
import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * 每日运营汇总表（用户数据看板）
 * 定时任务每日凌晨汇总前一天数据；当日数据由接口实时计算。
 */
@Data
@TableName("stat_daily_summary")
public class StatDailySummary {

    @TableId(type = IdType.AUTO)
    private Long id;

    /** 统计日期 */
    private LocalDate statDate;

    /** 日活跃用户数（当日有登录） */
    private Integer dau;

    /** 当日新增注册数 */
    private Integer newUsers;

    /** 截至当日累计注册数 */
    private Integer totalUsers;

    /** 当日峰值在线人数 */
    private Integer peakOnline;

    /** 当日平均在线人数 */
    private Integer avgOnline;

    @TableField(fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;
}
