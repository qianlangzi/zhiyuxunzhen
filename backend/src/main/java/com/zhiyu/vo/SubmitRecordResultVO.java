package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

/**
 * 提交大病历结果（PRD 4.4 / 5.3）
 */
@Data
@Builder
public class SubmitRecordResultVO {
    private Long instanceId;
    /** 校验后状态：2格式打回 / 3AI批阅中 */
    private Integer status;
    /** 格式校验是否通过 */
    private Boolean passed;
    /** 格式盾牌校验明细 */
    private FormatCheckResultVO formatCheckResult;
}
