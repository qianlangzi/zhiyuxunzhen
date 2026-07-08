package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 大病历格式盾牌校验结果（PRD 5.3）
 */
@Data
@Builder
public class FormatCheckResultVO {
    /** 是否通过 */
    private Boolean passed;

    /** 未通过时的错误说明列表 */
    private List<String> errors;

    /** 校验时间 */
    private LocalDateTime checkedAt;
}
