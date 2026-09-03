package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.util.List;
import java.util.Map;

/**
 * 作业进度统计（PRD 4.3）
 */
@Data
@Builder
public class AssignmentProgressVO {
    private Long assignmentId;
    private String assignmentTitle;

    /** 各状态学生数：notStarted/inProgress/formatRejected/aiReviewing/pendingReview/completed */
    private Map<String, Long> statusStats;

    /** 组合任务包:各任务项统计 */
    private List<AssignmentItemStatVO> itemStats;

    /** 学生明细列表 */
    private List<StudentProgressVO> students;
}
