package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.time.LocalDate;

/**
 * 病历缺陷命中记录表（V43）：学生病历能力画像 + 班级缺陷热力图的数据源。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("daily_case_defect")
public class DailyCaseDefect extends BaseEntity {

    private Long recordId;

    private Long scheduleId;

    private Long studentId;

    /** 所属段落 key，可空（通用缺陷） */
    private String segmentKey;

    /** 缺陷代码，对应 mr_defect_tag.code，如 CC_TOO_LONG */
    private String tagCode;

    /** 1轻微 2一般 3严重 */
    private Integer level;

    /** 冗余排期日期，便于按时间统计 */
    private LocalDate publishDate;
}
