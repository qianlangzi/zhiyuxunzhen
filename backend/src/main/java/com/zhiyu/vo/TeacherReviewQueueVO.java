package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;

@Data
@Builder
public class TeacherReviewQueueVO {
    private Long instanceId;
    private String studentName;
    private String assignmentTitle;
    private BigDecimal score;
    private String issue;
    private Integer instanceStatus;
    private Long latestReviewId;
}
