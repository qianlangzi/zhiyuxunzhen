package com.zhiyu.service;

import com.zhiyu.common.result.PageResult;
import com.zhiyu.vo.CaseMarketListVO;
import com.zhiyu.vo.CaseMarketDetailVO;

import java.util.List;

/**
 * 病例广场服务（PRD 4.2）
 */
public interface CaseMarketService {

    /**
     * 病例广场列表（仅公开且审核通过的病例），支持关键字搜索、科室/难度筛选与排序
     *
     * @param keyword    关键字，模糊匹配 标题 / 患者画像 / 知识点标签，为空不过滤
     * @param department 科室，模糊匹配（传「心血管」可命中「心血管内科」），为空不过滤
     */
    PageResult<CaseMarketListVO> list(Integer pageNum, Integer pageSize, String department,
                                      Integer difficulty, String keyword, String sortBy, String order);

    /**
     * 病例广场当前在售科室列表（动态去重）。
     *
     * <p>科室由教师创建病例时自由填写，无法预知全集，前端不应硬编码选项，
     * 一律由此接口下发，避免新增科室后筛选不到。
     */
    List<String> departments();

    /** 获取公开病例详情，不包含隐藏疾病和标准答案。 */
    CaseMarketDetailVO detail(Long caseId);

    /**
     * 引用病例：复制为当前教师的独立副本，原病例引用量+1，返回新病例ID
     */
    Long quote(Long caseId);
}
