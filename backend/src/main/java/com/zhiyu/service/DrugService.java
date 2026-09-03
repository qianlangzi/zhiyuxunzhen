package com.zhiyu.service;

import com.zhiyu.common.result.PageResult;
import com.zhiyu.vo.DrugDetailVO;
import com.zhiyu.vo.DrugFilterVO;
import com.zhiyu.vo.DrugListVO;

/** 药品库服务（训练中心 · 药房） */
public interface DrugService {

    /**
     * 药品库列表（仅上架 status=1），支持 药理分类精确 + 科室模糊 + 关键字模糊搜索
     *
     * @param category   药理分类（等值），为空不过滤
     * @param department 科室（LIKE，兼容「心血管」命中「心血管内科」），为空不过滤
     * @param keyword    关键字，模糊匹配 通用名/商品名/适应症，为空不过滤
     */
    PageResult<DrugListVO> list(Integer pageNum, Integer pageSize, String category,
                                String department, String keyword);

    /** 筛选维度：药理分类列表 + 科室列表（动态去重，供前端 chips 渲染） */
    DrugFilterVO filters();

    /** 药品详情（教学摘要） */
    DrugDetailVO detail(Long drugId);
}
