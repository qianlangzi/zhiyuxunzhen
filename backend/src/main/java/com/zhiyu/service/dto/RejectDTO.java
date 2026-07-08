package com.zhiyu.service.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

/**
 * 驳回审核请求（PRD 4.14 / 4.15）
 */
@Data
public class RejectDTO {

    @NotBlank(message = "驳回原因不能为空")
    private String reason;
}
