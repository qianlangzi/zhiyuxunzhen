package com.zhiyu.service;

import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.dto.TextbookCreateDTO;
import com.zhiyu.vo.TextbookVO;

import java.util.List;

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

    /**
     * 教师上传电子书元数据（创建上架教材）
     */
    Long create(TextbookCreateDTO dto);

    /**
     * 教师我的教材分页列表
     */
    PageResult<TextbookVO> myList(Integer pageNum, Integer pageSize);

    /**
     * 教师下架/删除自己的教材
     */
    void delete(Long id);

    /**
     * 教材科室分类列表（用于刷题/教材筛选入口）
     */
    List<String> departments();
}