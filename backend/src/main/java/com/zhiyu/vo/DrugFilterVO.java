package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.util.List;

/** 药品筛选维度：药理分类 + 科室（动态去重下发，供前端筛选项渲染） */
@Data
@Builder
public class DrugFilterVO {
    /** 药理分类列表（单值） */
    private List<String> categories;

    /** 科室列表（drug.department 为逗号分隔多值，拆分去重后下发） */
    private List<String> departments;
}
