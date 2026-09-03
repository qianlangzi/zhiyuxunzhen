package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

import java.time.LocalDateTime;

/**
 * 教材表
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("textbook")
public class Textbook extends BaseEntity {

    /** 统一教材号（如 JC000001） */
    private String textbookNo;

    /** 上传/创建教材的教师 ID */
    private Long creatorId;

    private String title;

    private String edition;

    /** 学科/科室 */
    private String department;

    private String author;

    private String publisher;

    private String coverUrl;

    /** 电子书文件地址（pdf/epub） */
    private String fileUrl;

    private String description;

    /** JSON 知识点数组 */
    private String knowledgeTags;

    private Integer chapterCount;

    /** 页数 */
    private Integer pageCount;

    /** 0下架 1上架 */
    private Integer status;

    /** 向量化入库状态：0未入库 1处理中 2已入库 3失败 */
    private Integer ingestStatus;

    /** 最近一次入库失败原因，成功或重新触发后清空 */
    private String ingestError;

    /** 最近一次触发向量化入库时间 */
    private LocalDateTime lastIngestAt;

    /** AI 中台最近一次入库任务 ID（回调携带，用于丢弃旧任务迟到回调） */
    private String ingestionId;

    /** 管理端累计触发入库次数（含重试/重新入库） */
    private Integer ingestRetryCount;

    /** 自动对账（定时任务）重试次数，独立于管理员手动触发计数 */
    private Integer ingestAutoRetryCount;

    /** 最近一次入库触发来源：1管理员手动 2定时自动对账 */
    private Integer ingestTriggerSource;

    /** 入库触发来源：管理员手动 */
    public static final int INGEST_TRIGGER_MANUAL = 1;

    /** 入库触发来源：定时自动对账 */
    public static final int INGEST_TRIGGER_AUTO = 2;
}
