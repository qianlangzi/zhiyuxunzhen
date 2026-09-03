package com.zhiyu.service.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

/**
 * 教师创建 / 重命名班级请求
 */
@Data
public class TeachingClassCreateDTO {

    @Schema(description = "班级名称")
    @NotBlank(message = "班级名称不能为空")
    @Size(max = 50, message = "班级名称过长")
    private String name;

    @Schema(description = "年级，如 2022 / 大四")
    @Size(max = 20, message = "年级信息过长")
    private String grade;
}