package com.zhiyu.service;

import com.zhiyu.service.dto.ReviewOverrideDTO;
import com.zhiyu.vo.TeacherReviewVO;

/**
 * 教师复核 AI 批阅服务（PRD 4.4.4 / 5.3 第 7 步）
 */
public interface TeacherReviewService {

    /**
     * 查询某作业实例最新的批阅记录（优先返回教师覆盖记录，否则返回 AI 批阅）
     */
    TeacherReviewVO getReview(Long instanceId);

    /**
     * 教师人工覆盖 AI 批阅结果，最终成绩以教师复核为准
     *
     * @param instanceId 作业实例 ID
     * @param dto        覆盖请求
     * @return 教师批阅记录 ID
     */
    Long overrideReview(Long instanceId, ReviewOverrideDTO dto);
}
