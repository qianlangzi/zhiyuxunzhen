package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 备课发布请求
 * materialOnly=true 仅发资料（不绑定作业）；false 则资料+病例+作业一起下发。
 */
@Data
public class LessonPublishDTO {

    @NotEmpty(message = "至少选择一个班级")
    private List<Long> classIds;

    /** true 仅发资料 / false 资料+病例+作业 */
    private Boolean materialOnly;

    /** 是否要求大病历（materialOnly=false 时生效） */
    private Boolean requireMedicalRecord;

    /** 作业标题（materialOnly=false 时生效，默认取备课标题） */
    private String assignmentTitle;

    private LocalDateTime deadline;
}
