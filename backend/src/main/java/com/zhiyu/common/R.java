package com.zhiyu.common;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 统一响应体（PRD 16.3.3）
 * code: 0 成功 / 1xxx 客户端错误 / 2xxx 业务错误 / 5xxx 服务端错误
 */
@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class R<T> {
    private int code;
    private String message;
    private T data;

    public static <T> R<T> ok() {
        return R.<T>builder().code(0).message("ok").build();
    }

    public static <T> R<T> ok(T data) {
        return R.<T>builder().code(0).message("ok").data(data).build();
    }

    public static <T> R<T> fail(int code, String message) {
        return R.<T>builder().code(code).message(message).build();
    }

    public static <T> R<T> fail(com.zhiyu.common.constant.ResultCode rc) {
        return R.<T>builder().code(rc.getCode()).message(rc.getMessage()).build();
    }

    public static <T> R<T> fail(com.zhiyu.common.constant.ResultCode rc, String message) {
        return R.<T>builder().code(rc.getCode()).message(message).build();
    }
}
