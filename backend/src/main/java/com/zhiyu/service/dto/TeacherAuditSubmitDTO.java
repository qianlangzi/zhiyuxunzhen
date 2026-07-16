package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

/**
 * 教师资质认证提交请求（PRD 9.1）
 * 教师提交资质材料将 audit_status 从 0(未提交)/3(驳回) → 1(待审核)
 */
@Data
public class TeacherAuditSubmitDTO {

    /** 执业医师证号或教师工号 */
    @NotBlank(message = "执业医师证号/教师工号不能为空")
    private String certificateNo;

    /** 教学授权材料 URL（可由文件网关返回） */
    private String certificateUrl;

    /** 所属科室 */
    private String department;

    /** 资质说明（可选） */
    private String remark;
}
