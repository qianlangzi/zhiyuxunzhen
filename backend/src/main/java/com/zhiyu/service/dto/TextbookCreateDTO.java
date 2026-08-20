package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

import java.util.List;

/**
 * 教材创建 DTO（教师上传电子书元数据）
 */
@Data
public class TextbookCreateDTO {

    @NotBlank(message = "书名不能为空")
    private String title;

    private String edition;

    /** 学科/科室分类 */
    private String department;

    private String author;

    private String publisher;

    /** 电子书文件地址（由上传接口返回） */
    private String fileUrl;

    private String coverUrl;

    private String description;

    /** 知识点标签 */
    private List<String> knowledgeTags;

    private Integer chapterCount;

    private Integer pageCount;
}