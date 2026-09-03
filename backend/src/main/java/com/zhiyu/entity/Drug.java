package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

/**
 * 药品库实体（训练中心 · 药房）
 *
 * <p>科室(多值) × 药理分类 双维结构化数据，供学生端分门别类浏览 / 检索。
 * 内容为内科教学演示摘要，仅作参考，不替代说明书与医嘱。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("drug")
public class Drug extends BaseEntity {

    /** 通用名（主展示名） */
    private String genericName;

    /** 商品名 / 别名 */
    private String tradeName;

    /** 英文名 */
    private String englishName;

    /** 药理分类（如 β受体阻滞剂 / PPI / 双胍类） */
    private String category;

    /** 科室标签，多值逗号分隔（如 心血管内科,神经内科） */
    private String department;

    /** 剂型规格（如 肠溶片 100mg×30片） */
    private String dosageForm;

    /** 适应症 */
    private String indications;

    /** 用法用量（教学摘要） */
    private String usageDosage;

    /** 不良反应 */
    private String adverseReactions;

    /** 禁忌 */
    private String contraindications;

    /** 注意事项 */
    private String precautions;

    /** 是否非处方药：0处方 1非处方 */
    private Integer isOtc;

    /** 1上架 0下架 */
    private Integer status;

    /** 排序权重，越大越靠前 */
    private Integer sort;
}
