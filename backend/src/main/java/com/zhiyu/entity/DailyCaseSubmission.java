package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.time.LocalDateTime;

@Data
@EqualsAndHashCode(callSuper = true)
@TableName("daily_case_submission")
public class DailyCaseSubmission extends BaseEntity {
    private Long scheduleId;
    private Long studentId;
    private String answer;
    private Boolean isCorrect;
    private String evaluationJson;
    private LocalDateTime submittedAt;
}
