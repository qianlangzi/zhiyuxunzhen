package com.zhiyu.service.dto;

import lombok.Data;

import java.util.List;

/**
 * 教案拖动排序请求（lessonIds 按展示顺序传入）
 */
@Data
public class LessonSortDTO {

    /** 教案 ID 列表，按拖动后的展示顺序排列 */
    private List<Long> lessonIds;
}
