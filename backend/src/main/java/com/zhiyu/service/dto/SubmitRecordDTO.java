package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

/**
 * 学生提交大病历请求（PRD 4.4 / 5.3）
 */
@Data
public class SubmitRecordDTO {

    @NotBlank(message = "大病历正文不能为空")
    private String medicalRecordText;
}
