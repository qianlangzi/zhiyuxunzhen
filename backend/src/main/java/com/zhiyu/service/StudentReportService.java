package com.zhiyu.service;

import com.zhiyu.service.dto.ExportReportDTO;
import com.zhiyu.vo.ReviewReportVO;
import com.zhiyu.vo.StudentLearningOverviewVO;

/**
 * 学生复盘报告服务（PRD 4.11）
 */
public interface StudentReportService {

    /**
     * 导出复盘报告：汇总指定会话/日期范围的问诊数据，并写审计日志
     */
    ReviewReportVO export(ExportReportDTO req);

    StudentLearningOverviewVO overview();
}
