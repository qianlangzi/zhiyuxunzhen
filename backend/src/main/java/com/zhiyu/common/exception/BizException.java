package com.zhiyu.common.exception;

import com.zhiyu.common.constant.ResultCode;
import lombok.Getter;

/**
 * 业务异常，携带错误码
 */
@Getter
public class BizException extends RuntimeException {
    private final int code;

    public BizException(ResultCode rc) {
        super(rc.getMessage());
        this.code = rc.getCode();
    }

    public BizException(ResultCode rc, String message) {
        super(message);
        this.code = rc.getCode();
    }

    public BizException(int code, String message) {
        super(message);
        this.code = code;
    }
}
