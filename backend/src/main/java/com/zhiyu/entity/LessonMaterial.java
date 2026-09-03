package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableLogic;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

/**
 * 备课资料（课件资料库：PDF/PPT/MP4/MP3/图片）
 * 资料可随备课发布，也可独立发放给学生（material_only）。
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("lesson_material")
public class LessonMaterial extends BaseEntity {

    private Long lessonId;

    /** pdf/ppt/mp4/mp3/image */
    private String materialType;

    private String title;

    private String fileUrl;

    private String objectKey;

    /** 知识点标签 JSON */
    private String knowledgeTags;

    /** PDF/PPT 提取文本（入知识库用） */
    private String ocrText;

    /** 音视频时长（秒） */
    private Integer durationSec;

    @TableLogic
    private Integer isDeleted;
}
