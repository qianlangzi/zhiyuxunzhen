package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

@Data
@Builder
public class RegistrationResponse {
    private Long userId;
    private String username;
    private Integer role;
    private Integer auditStatus;
    private String message;
}
