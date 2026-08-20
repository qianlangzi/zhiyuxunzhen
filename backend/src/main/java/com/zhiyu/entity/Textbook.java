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
}