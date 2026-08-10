package com.zhiyu.common.constant;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 错误码枚举（PRD 16.3.3）
 * 0 成功 / 1xxx 客户端错误 / 2xxx 业务错误 / 5xxx 服务端错误
 */
@Getter
@AllArgsConstructor
public enum ResultCode {

    SUCCESS(0, "success"),

    // ---------- 1xxx 客户端错误 ----------
    BAD_REQUEST(1400, "请求参数错误"),
    UNAUTHORIZED(1001, "未登录或token无效"),
    TOKEN_EXPIRED(1002, "token已过期"),
    FORBIDDEN(1003, "无权限访问"),
    NOT_FOUND(1404, "资源不存在"),
    METHOD_NOT_ALLOWED(1405, "请求方法不允许"),
    VALIDATION_FAILED(1422, "参数校验失败"),

    // ---------- 2xxx 业务错误 ----------
    USERNAME_OR_PASSWORD_ERROR(2001, "用户名或密码错误"),
    ACCOUNT_FROZEN(2002, "账号已冻结"),
    TEACHER_NOT_AUDITED(2003, "教师资质未认证，请先完成资质审核"),
    TEACHER_AUDIT_PENDING(2004, "资质审核中，请耐心等待"),
    TEACHER_AUDIT_REJECTED(2005, "资质审核未通过"),
    USERNAME_EXISTS(2006, "用户名已存在"),
    PHONE_OR_CODE_ERROR(2007, "手机号或验证码错误"),
    SMS_CODE_TOO_FREQUENT(2008, "验证码发送过于频繁，请稍后再试"),
    SMS_SERVICE_NOT_CONFIGURED(2009, "短信服务未配置"),
    PHONE_EXISTS(2010, "手机号已注册"),
    CAPTCHA_INVALID(2011, "图形验证码错误或已失效"),
    CAPTCHA_TOO_FREQUENT(2012, "验证码请求过于频繁，请稍后再试"),
    IP_SMS_LIMIT(2013, "该IP请求验证码过于频繁，请稍后再试"),
    PASSWORD_SAME_AS_OLD(2014, "新密码不能与原密码相同"),
    PASSWORD_CHANGE_REQUIRED(2015, "需要修改初始密码后才能使用"),
    CASE_NOT_FOUND(2101, "病例不存在"),
    ASSIGNMENT_NOT_FOUND(2102, "作业不存在"),
    INSTANCE_NOT_FOUND(2103, "作业实例不存在"),
    FORMAT_CHECK_FAILED(2104, "大病历格式校验未通过"),
    ASSIGNMENT_DEADLINE_PASSED(2105, "作业已截止提交"),
    DUPLICATE_SUBMIT(2106, "请勿重复提交"),
    CASE_REFERENCED(2107, "病例已被作业引用，核心诊断字段不可修改"),
    CASE_NOT_QUOTABLE(2108, "该病例未公开或未通过审核，不可引用"),

    // ---------- 5xxx 服务端错误 ----------
    INTERNAL_ERROR(5000, "系统内部错误"),
    AI_SERVICE_ERROR(5001, "AI服务调用异常"),
    DB_ERROR(5002, "数据库异常"),
    FILE_UPLOAD_ERROR(5003, "文件上传失败");

    private final int code;
    private final String message;
}
