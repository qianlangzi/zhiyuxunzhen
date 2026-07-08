package com.zhiyu.service;

import com.zhiyu.common.result.PageResult;
import com.zhiyu.vo.MistakeVO;

/**
 * 学生错题本服务（PRD 4.11）
 */
public interface StudentMistakeService {

    /**
     * 我的错题本列表（分页，支持类型筛选）
     */
    PageResult<MistakeVO> myMistakes(Integer pageNum, Integer pageSize, String mistakeType);
}
