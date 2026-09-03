package com.zhiyu.service.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class RegisterRequest {

    @NotBlank(message = "账号不能为空")
    @Pattern(regexp = "^[A-Za-z0-9_]{4,32}$", message = "账号须为 4-32 位字母、数字或下划线")
    private String username;

    @NotBlank(message = "密码不能为空")
    @Size(min = 8, max = 64, message = "密码长度须为 8-64 位")
    @Pattern(regexp = "^(?=.*[A-Za-z])(?=.*\\d).+$", message = "密码必须同时包含字母和数字")
    private String password;

    @NotBlank(message = "姓名不能为空")
    @Size(min = 2, max = 50, message = "姓名长度须为 2-50 位")
    private String realName;

    @NotBlank(message = "手机号不能为空")
    @Pattern(regexp = "^1[3-9]\\d{9}$", message = "请输入正确的 11 位手机号")
    private String phone;

    @NotBlank(message = "验证码不能为空")
    @Pattern(regexp = "^\\d{6}$", message = "验证码须为 6 位数字")
    private String code;

    @NotNull(message = "请选择注册身份")
    @Min(value = 0, message = "注册身份无效")
    @Max(value = 1, message = "注册身份无效")
    private Integer role;

    /** 学校名称（学生与教师均必填） */
    @NotBlank(message = "学校不能为空")
    @Size(max = 100, message = "学校名称不能超过 100 位")
    private String schoolName;

    /** 学生年级（学生必填） */
    @Size(max = 20, message = "年级不能超过 20 位")
    private String grade;

    /** 学生班级名称（学生必填） */
    @Size(max = 50, message = "班级名称不能超过 50 位")
    private String className;

    /** 教师资质编号（教师必填） */
    @Size(max = 100, message = "资质编号不能超过 100 位")
    private String certificateNo;

    /** 教师所属科室（教师必填） */
    @Size(max = 100, message = "科室名称不能超过 100 位")
    private String department;

    /** 教师资质证书图片路径（教师必填，由上传接口返回） */
    @Size(max = 255, message = "证书图片路径过长")
    private String teacherCertificateImage;
}
