package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

/**
 * 趋势折线图数据点（用户数据看板）
 */
@Data
@Builder
public class TrendPointVO {

    /** 横轴标签：在线走势为 "HH:mm"，日趋势为 "MM-dd" */
    private String label;

    /** 总在线/总活跃 */
    private Integer total;

    /** 学生数 */
    private Integer students;

    /** 教师数 */
    private Integer teachers;

    /** 当日新增注册（仅日趋势有值） */
    private Integer newUsers;
}
