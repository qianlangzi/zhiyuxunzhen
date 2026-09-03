package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.util.Map;

/**
 * 练习交卷 / 阅读完成 结果（组合任务包）
 */
@Data
@Builder
public class PracticeSubmitResultVO {
    private Long itemProgressId;
    /** 0未开始 1进行中 2已提交/格式打回 3AI批阅中 4待复核 5已完成 */
    private Integer status;
    private BigDecimal score;
    /** 总题数（阅读任务为 null） */
    private Integer total;
    /** 答对数（阅读任务为 null） */
    private Integer correct;
    /** 每题判分明细 questionId -> 是否答对（阅读任务为 null） */
    private Map<Long, Boolean> result;
}
