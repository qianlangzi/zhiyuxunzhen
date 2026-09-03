package com.zhiyu.service.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

/**
 * 学生通过邀请码加入班级请求
 */
@Data
public class TeachingClassJoinDTO {

    @Schema(description = "班级邀请码")
    @NotBlank(message = "邀请码不能为空")
    @Size(max = 32, message = "邀请码格式不正确")
    private String inviteCode;
}