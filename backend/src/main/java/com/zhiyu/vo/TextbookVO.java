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
}