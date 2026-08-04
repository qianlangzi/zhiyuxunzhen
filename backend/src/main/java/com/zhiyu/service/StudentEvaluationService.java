package com.zhiyu.service;

import com.zhiyu.vo.SessionEvaluationVO;
import com.zhiyu.vo.ThinkingTreeVO;

/**
 * 学生会话评估服务
 */
public interface StudentEvaluationService {

    /**
     * 获取会话 OSCE 评估结果
     */
    SessionEvaluationVO getEvaluation(Long sessionId);

    /**
     * 获取思维树数据
     */
    ThinkingTreeVO getThinkingTree(Long sessionId);
}