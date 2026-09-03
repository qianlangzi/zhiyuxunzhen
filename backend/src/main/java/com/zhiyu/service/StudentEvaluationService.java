package com.zhiyu.service;

import com.zhiyu.vo.OsceHistoryVO;
import com.zhiyu.vo.SessionEvaluationVO;
import com.zhiyu.vo.ThinkingTreeVO;

import java.util.List;

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

    /**
     * OSCE 考核历史记录列表（已完成会话，按时间倒序）
     */
    List<OsceHistoryVO> history();
}