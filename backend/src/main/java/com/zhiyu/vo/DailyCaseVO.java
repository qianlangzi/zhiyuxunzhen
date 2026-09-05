package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDate;

/**
 * 每日一例展示 VO（PRD 4.10）
 */
@Data
@Builder
public class DailyCaseVO {

    private Long scheduleId;

    private Long caseId;

    private String caseTitle;

    private String department;

    private Integer difficulty;

    private LocalDate publishDate;

    private String targetGrade;

    /** 患者画像（来自病例配置，用于开放作答展示） */
    private String patientProfile;

    /** 关键检查结果展示文本（由 presetExams 格式化生成） */
    private String keyFindings;

    /** 当前学生对今日病例的问诊状态：null未做过 / 0进行中 / 1已完成 / 2评估异常（按用户实时计算，不入全局缓存） */
    private Integer lastSessionStatus;

    private String question;

    private String optionsJson;

    private String textbookRef;

    /** 0草稿 1已排期 2已发布 */
    private Integer status;
}
