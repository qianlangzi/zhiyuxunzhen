package com.zhiyu.service;

import com.zhiyu.vo.TeacherDashboardVO;

/**
 * 教师学情看板服务
 */
public interface TeacherDashboardService {

    /**
     * 获取教师学情概览
     */
    TeacherDashboardVO getOverview(Long teacherId);
}