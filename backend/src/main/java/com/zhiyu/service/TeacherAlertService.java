package com.zhiyu.service;

import java.util.List;
import java.util.Map;

/**
 * 学情预警服务（助教：学情精准诊断）
 * Rule-first 规则引擎 + AI 干预建议 + 站内信推送
 */
public interface TeacherAlertService {

    /** 触发全量预警扫描（Rule-first 规则引擎；可由定时任务调用） */
    void scan();

    /** 班级预警总览（风险学生数/类型分布/待处理数） */
    Map<String, Object> overview();

    /** 预警学生列表（按班级/风险等级过滤） */
    List<Map<String, Object>> list(Long classId, Integer level);

    /** 单个学生预警详情（规则明细 + 干预建议缓存） */
    Map<String, Object> detail(Long studentId);

    /** 为单个学生生成 AI 干预建议（调用 AI 中台 /insight/alert，缓存到 student_alert） */
    Map<String, Object> intervene(Long studentId);

    /** 标记预警已处理 */
    void markResolved(Long alertId);
}
