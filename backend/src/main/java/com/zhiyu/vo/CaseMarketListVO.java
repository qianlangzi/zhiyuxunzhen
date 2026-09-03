package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 病例广场列表项（PRD 4.2）
 */
@Data
@Builder
public class CaseMarketListVO {
    private Long id;
    /** 病例内部标题（含病名，仅管理/教师端展示；学生端一律用 department+caseNo 显示，防泄露答案） */
    private String title;
    private String department;
    /** 病号=题号：学生端展示「科室 · No.xx」 */
    private String caseNo;
    private Integer difficulty;
    private BigDecimal ratingAvg;
    private Integer referenceCount;
    private String creatorName;
    private String knowledgeTags;
    private LocalDateTime createdAt;
    /** 当前学生最近一次问诊会话ID（未做过为 null） */
    private Long lastSessionId;
    /** 当前学生最近一次问诊状态：null未做过 0进行中(可继续) 1已完成(可看报告) 2评估异常(可重试) */
    private Integer lastSessionStatus;
}
