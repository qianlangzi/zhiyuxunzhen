package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

/** 药品库列表项（训练中心 · 药房） */
@Data
@Builder
public class DrugListVO {
    private Long id;
    private String genericName;
    private String tradeName;
    private String englishName;
    private String category;
    private String department;
    private String dosageForm;
    private Integer isOtc;
}
