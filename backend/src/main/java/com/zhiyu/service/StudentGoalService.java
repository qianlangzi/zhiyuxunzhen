package com.zhiyu.service;

import com.zhiyu.entity.StudentGoal;

/**
 * 学生学习目标服务（P2-1 学习档案/目标管理）
 */
public interface StudentGoalService {

    /**
     * 获取我的当前目标（最近一条）
     */
    StudentGoal myGoal();

    /**
     * 设定/更新我的目标（同一学生只保留一条，upsert 语义）
     */
    Long upsert(String title, String targetMetric, String targetDate);
}
