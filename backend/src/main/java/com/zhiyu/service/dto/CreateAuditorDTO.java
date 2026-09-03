package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

/**
 * 创建普通审核员账号请求（超级管理员 role=4 专属）
 * 用于在管理端开通 role=6（普通审核员）：仅可访问审核中心。
 */
@Data
public class CreateAuditorDTO {

    @NotBlank(message = "账号不能为空")
    @Size(min = 3, max = 32, message = "账号长度需在 3-32 之间")
    private String username;

    @NotBlank(message = "密码不能为空")
    @Size(min = 6, max = 32, message = "密码长度需在 6-32 之间")
    private String password;

    @NotBlank(message = "姓名不能为空")
    @Size(max = 32, message = "姓名过长")
    private String realName;

    @Size(max = 64, message = "科室过长")
    private String department;
}