package com.zhiyu.service;

import com.zhiyu.common.result.PageResult;
import com.zhiyu.entity.StudentFeedback;

/**
 * 学生反馈与试用埋点服务（P2-3 真实用户数据）
 */
public interface StudentFeedbackService {

    /**
     * 提交反馈
     */
    Long submit(String category, Integer rating, String content);

    /**
     * 我的反馈列表（分页）
     */
    PageResult<StudentFeedback> myFeedback(Integer pageNum, Integer pageSize);

    /**
     * 关键动作轻量埋点（append-only，无更新）
     */
    void track(String action, String detail);
}
