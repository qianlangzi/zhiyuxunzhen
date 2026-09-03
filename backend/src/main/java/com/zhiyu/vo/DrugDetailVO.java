package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

/** 药品详情（说明书式教学摘要） */
@Data
@Builder
public class DrugDetailVO {
    private Long id;
    private String genericName;
    private String tradeName;
    private String englishName;
    private String category;
    private String department;
    private String dosageForm;
    private Integer isOtc;
    private String indications;
    private String usageDosage;
    private String adverseReactions;
    private String contraindications;
    private String precautions;
}
