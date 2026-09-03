package com.zhiyu.service.dto;

import lombok.Data;

import java.util.List;

/**
 * 教案批量管理请求（多选删除 / 智能合并）
 */
@Data
public class LessonBatchDTO {

    /** 参与操作的教案 ID 列表（合并时按顺序，首个为基础载体） */
    private List<Long> ids;

    /** 合并后的标题（仅合并时使用，为空则沿用首个教案标题） */
    private String title;
}