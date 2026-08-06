package com.zhiyu.service;

import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.dto.PracticeAnswerDTO;
import com.zhiyu.vo.PracticeQuestionVO;
import com.zhiyu.vo.PracticeStatsVO;
import com.zhiyu.vo.SubmitResultVO;

/**
 * 基础题训练服务
 */
public interface PracticeQuestionService {

    /**
     * 基础题分页列表（支持知识点/难度/题型筛选）
     */
    PageResult<PracticeQuestionVO> page(Integer pageNum, Integer pageSize,
                                        String knowledgeTag, Integer difficulty, String questionType);

    /**
     * 题目详情
     */
    PracticeQuestionVO detail(Long id);

    /**
     * 提交答案并判题，记录练习记录
     */
    SubmitResultVO submit(PracticeAnswerDTO dto);

    /**
     * 我的训练统计
     */
    PracticeStatsVO stats();
}