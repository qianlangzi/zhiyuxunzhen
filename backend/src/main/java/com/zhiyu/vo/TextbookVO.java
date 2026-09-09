package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.util.List;

/**
 * 教材列表/详情 VO
 */
@Data
@Builder
public class TextbookVO {
    private Long id;
    /** 统一教材号（如 JC000001） */
    private String textbookNo;
    private String title;
    private String edition;
    /** 学科/科室 */
    private String department;
    private String author;
    private String publisher;
    private String coverUrl;
    /** 电子书文件地址 */
    private String fileUrl;
    private String description;
    /** 知识点列表 */
    private List<String> knowledgeTags;
    private Integer chapterCount;
    private Integer pageCount;
    /** 向量化入库状态：0未入库 1处理中(后台整理) 2已入库 3失败 */
    private Integer ingestStatus;
    /** 是否由当前登录教师创建（教材库列表用于打「我上传的」徽章；我的教材列表恒为 true） */
    private Boolean mine;
}