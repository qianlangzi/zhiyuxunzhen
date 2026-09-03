package com.zhiyu.service;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

/**
 * 批阅申诉（学生发起 → 教师处理）
 */
public interface ReviewAppealService {

    /** 学生发起申诉：instanceId 定位最新批阅结果并建档 */
    Long create(Long instanceId, String reason);

    /** 学生端：我的申诉列表 */
    List<Map<String, Object>> myAppeals();

    /** 教师端：申诉列表（status 为空=全部，否则按状态过滤） */
    List<Map<String, Object>> teacherAppeals(Integer status);

    /** 教师处理申诉：status(1已处理/2驳回) + reply；newScore 非空时同步更新该批阅得分 */
    void handle(Long appealId, Integer status, String reply, BigDecimal newScore);
}