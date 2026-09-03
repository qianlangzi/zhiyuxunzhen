package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

/**
 * 管理端-教材列表项（含入库状态、上架状态、上传教师）
 */
@Data
@Builder
public class TextbookAdminVO {
    private Long id;
    private String title;
    private String edition;
    /** 学科/科室 */
    private String department;
    private String author;
    private String publisher;
    private String coverUrl;
    private String fileUrl;
    private String description;
    private Integer pageCount;
    /** 0下架 1上架 */
    private Integer status;
    /** 向量化入库状态：0未入库 1处理中 2已入库 3失败 */
    private Integer ingestStatus;
    private String ingestError;
    private LocalDateTime lastIngestAt;
    /** AI 中台最近一次入库任务 ID */
    private String ingestionId;
    /** 累计触发入库次数（含重试/重新入库） */
    private Integer ingestRetryCount;
    /** 自动对账（定时任务）重试次数，独立于管理员手动触发计数 */
    private Integer ingestAutoRetryCount;
    /** 最近一次入库触发来源：1管理员手动 2定时自动对账 */
    private Integer ingestTriggerSource;
    private Long creatorId;
    private String creatorName;
    private LocalDateTime createdAt;
}
