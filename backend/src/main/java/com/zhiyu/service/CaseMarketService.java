package com.zhiyu.service;

import com.zhiyu.common.result.PageResult;
import com.zhiyu.vo.CaseMarketListVO;
import com.zhiyu.vo.CaseMarketDetailVO;

/**
 * 病例广场服务（PRD 4.2）
 */
public interface CaseMarketService {

    /**
     * 病例广场列表（仅公开且审核通过的病例），支持科室/难度筛选与排序
     */
    PageResult<CaseMarketListVO> list(Integer pageNum, Integer pageSize, String department,
                                      Integer difficulty, String sortBy, String order);

    /** 获取公开病例详情，不包含隐藏疾病和标准答案。 */
    CaseMarketDetailVO detail(Long caseId);

    /**
     * 引用病例：复制为当前教师的独立副本，原病例引用量+1，返回新病例ID
     */
    Long quote(Long caseId);
}
