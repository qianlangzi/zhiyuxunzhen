package com.zhiyu.service;

import com.zhiyu.vo.StudentLearningOverviewVO;

/**
 * 学生成长概览服务（原复盘报告链路的 export 已于 2026-09-02 下线）
 */
public interface StudentReportService {

    /**
     * 成长页概览：能力评分（OSCE 四维均值）+ 近 90 天活动热力图
     */
    StudentLearningOverviewVO overview();
}
