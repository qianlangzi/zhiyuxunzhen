package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/**
 * 每日病历 · 题目详情 VO（书写工坊页数据源）
 */
@Data
@Builder
public class DailyMrDetailVO {

    private Long scheduleId;

    private String caseTitle;

    private String department;

    private Integer difficulty;

    private LocalDate publishDate;

    private String patientProfile;

    private String keyFindings;

    /** 标准诊断要点：提交过至少一次后才下发（防止照抄） */
    private String standardAnswer;

    /** 参考病历：提交过至少一次后才下发 */
    private String referenceRecord;

    /** 患者自带影像/报告附件（教师上传的多模态素材，仅暴露图片不暴露结论防剧透） */
    private List<java.util.Map<String, Object>> exams;

    /** 九段定义（key/名称/规范说明/满分/段序） */
    private List<SegmentSpec> segments;

    /** 我的提交记录（按版本倒序） */
    private List<MyRecord> myRecords;

    @Data
    @Builder
    public static class SegmentSpec {
        private String key;
        private String name;
        private String spec;
        private Integer order;
        private Integer fullScore;
    }

    @Data
    @Builder
    public static class MyRecord {
        private Long recordId;
        private Integer version;
        private Integer status;
        private BigDecimal totalScore;
        private BigDecimal aiConfidence;
        private String contentJson;
        private String reviewJson;
        private String teacherComment;
        private String submittedAt;
    }
}
