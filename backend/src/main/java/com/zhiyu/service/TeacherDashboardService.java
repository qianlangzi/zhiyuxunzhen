package com.zhiyu.service;

import com.zhiyu.vo.TeacherDashboardVO;

/**
 * 教师学情看板服务
 */
public interface TeacherDashboardService {

    /**
     * 获取教师学情概览
     *
     * @param teacherId 教师 id
     * @param classId   可选，指定班级时按该班学生维度汇总学情统计（myCases/classCount/广场统计仍为该教师全局）
     */
    TeacherDashboardVO getOverview(Long teacherId, Long classId);
}