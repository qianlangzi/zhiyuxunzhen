package com.zhiyu.service;

import com.zhiyu.common.result.PageResult;
import com.zhiyu.vo.MistakeVO;

import java.util.Map;

/**
 * 学生错题本服务（PRD 4.11）
 */
public interface StudentMistakeService {

    /**
     * 我的错题本列表（分页，支持类型筛选）
     */
    PageResult<MistakeVO> myMistakes(Integer pageNum, Integer pageSize, String mistakeType);

    /**
     * 单条错题 AI 归因（缓存命中直接返回；未命中调用 AI 并持久化缓存；
     * AI 不可用时返回 status=DEGRADED 的可重试提示）
     */
    Map<String, Object> analyzeMistake(Long mistakeId);
}
