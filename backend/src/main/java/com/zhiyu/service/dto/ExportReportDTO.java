package com.zhiyu.service.dto;

import lombok.Data;

import java.time.LocalDate;
import java.util.List;

/**
 * 学生导出复盘报告请求（PRD 4.11）
 * 可按会话ID列表或日期范围筛选
 */
@Data
public class ExportReportDTO {

    /** 指定会话ID列表（可选） */
    private List<Long> sessionIds;

    /** 起始日期（可选，含） */
    private LocalDate dateStart;

    /** 结束日期（可选，含） */
    private LocalDate dateEnd;
}
