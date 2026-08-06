package com.zhiyu.service;

import com.zhiyu.common.result.PageResult;
import com.zhiyu.vo.TextbookVO;

/**
 * 教材中心服务
 */
public interface TextbookService {

    /**
     * 教材分页列表（支持科室筛选 + 关键词搜索）
     */
    PageResult<TextbookVO> page(Integer pageNum, Integer pageSize, String department, String keyword);

    /**
     * 教材详情
     */
    TextbookVO detail(Long id);
}