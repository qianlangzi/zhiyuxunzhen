package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

/**
 * 教材表
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("textbook")
public class Textbook extends BaseEntity {

    private String title;

    private String edition;

    /** 学科/科室 */
    private String department;

    private String author;

    private String publisher;

    private String coverUrl;

    private String description;

    /** JSON 知识点数组 */
    private String knowledgeTags;

    private Integer chapterCount;

    /** 0下架 1上架 */
    private Integer status;
}