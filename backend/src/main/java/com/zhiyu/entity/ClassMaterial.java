package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableLogic;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

/**
 * 班级资料库（班级详情「资料」板块）
 * source_type=upload 教师自行上传；source_type=textbook 引用教材库教材。
 * 学生端「我的课程-班级详情」可查看，随存随看，不进待办闭环。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("class_material")
public class ClassMaterial extends BaseEntity {

    private Long classId;

    /** upload / textbook */
    private String sourceType;

    /** pdf/ppt/doc/docx/txt/epub/mp4/mp3/image/link */
    private String materialType;

    private String title;

    private String fileUrl;

    private String objectKey;

    /** source_type=textbook 时的教材引用 */
    private Long textbookId;

    /** 音视频时长（秒） */
    private Integer durationSec;

    private Long creatorId;

    @TableLogic
    private Integer isDeleted;
}
