package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

@Data
@Builder
public class TeacherAssignmentListVO {
    private Long id;
    private String title;
    private Long caseId;
    private String caseTitle;
    private LocalDateTime deadline;
    private Integer status;
    private Boolean requireMedicalRecord;
    private String antiCheatVariables;
    private List<String> classNames;
    private Long submittedCount;
    private Long studentCount;
}
