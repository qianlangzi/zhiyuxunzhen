package com.zhiyu.vo;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Value;

@Value
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class SmsCodeResponse {
    boolean sent;
    int expiresIn;
    String devCode;
}
