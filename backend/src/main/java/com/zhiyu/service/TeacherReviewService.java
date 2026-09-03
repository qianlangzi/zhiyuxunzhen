package com.zhiyu.service;

import com.zhiyu.service.dto.EssayReviewDTO;
import com.zhiyu.service.dto.ReviewOverrideDTO;
import com.zhiyu.vo.TeacherReviewVO;
import com.zhiyu.vo.TeacherReviewQueueVO;
import java.util.List;
import java.util.Map;

/**
 * 教师复核 AI 批阅服务（PRD 4.4.4 / 5.3 第 7 步）
 */
public interface TeacherReviewService {

    List<TeacherReviewQueueVO> list(Long classId);

    /**
     * 主观题（简答/论述）AI 批阅：按教师自定义评分要点批阅，返回维度评分与改进建议。
     * AI 中台不可用时抛 AI_SERVICE_ERROR（教师端可重试）。
     */
    Map<String, Object> essayReview(EssayReviewDTO dto);

    /**
     * 查询主观题批阅任务上下文（题目/评分要点/学生答案/关联ID），供教师端批改页展示。
     *
     * @param itemProgressId 任务项进度 ID
     * @return 上下文 Map；数据不可用或不属于该教师时返回 null（移动端展示"暂无数据"）
     */
    Map<String, Object> getEssayTask(Long itemProgressId);

    /**
     * 查询批阅记录（优先返回教师覆盖记录，否则返回 AI 批阅）
     *
     * @param instanceId     作业实例 ID（存量/组合包均传实例ID）
     * @param itemProgressId 组合包任务项进度 ID（可选，存量作业传 null）
     */
    TeacherReviewVO getReview(Long instanceId, Long itemProgressId);

    /**
     * 教师人工覆盖 AI 批阅结果，最终成绩以教师复核为准
     *
     * @param instanceId     作业实例 ID
     * @param itemProgressId 组合包任务项进度 ID（可选，存量作业传 null）
     * @param dto            覆盖请求
     * @return 教师批阅记录 ID
     */
    Long overrideReview(Long instanceId, Long itemProgressId, ReviewOverrideDTO dto);
}
