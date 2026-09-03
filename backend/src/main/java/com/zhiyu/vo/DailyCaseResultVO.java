package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class DailyCaseResultVO {
    private Long scheduleId;
    private Boolean evaluated;
    private Boolean correct;
    private String correctAnswer;
    private String explanation;
    private String textbookRef;
    private Boolean degraded;
}
