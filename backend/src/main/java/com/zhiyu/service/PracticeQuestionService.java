package com.zhiyu.service;

import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.dto.PracticeAnswerDTO;
import com.zhiyu.vo.PracticeQuestionVO;
import com.zhiyu.vo.PracticeStatsVO;
import com.zhiyu.vo.SubmitResultVO;

import java.util.List;

/**
 * 基础题训练服务
 */
public interface PracticeQuestionService {

    /**
     * 基础题分页列表（支持科室/知识点/难度/题型筛选）
     */
    PageResult<PracticeQuestionVO> page(Integer pageNum, Integer pageSize,
                                        String department, String knowledgeTag,
                                        Integer difficulty, String questionType);

    /**
     * 基础题分页列表：按科室刷题，可指定起始难度进阶（返回该科室题目，支持翻页）
     */
    PageResult<PracticeQuestionVO> pageByDepartment(Integer pageNum, Integer pageSize,
                                                    String department, Integer difficulty);

    /**
     * 科室（模块）列表：用于刷题入口选择
     */
    List<String> departments();

    /**
     * 知识点列表：用于题库筛选
     */
    List<String> knowledgeTags();

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