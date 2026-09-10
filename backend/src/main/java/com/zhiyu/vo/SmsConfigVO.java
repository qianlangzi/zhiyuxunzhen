package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.util.List;

/**
 * 管理端-短信服务商配置视图（用于热切换）
 */
@Data
@Builder
public class SmsConfigVO {

    /** 当前生效的 provider：aliyun_auth / juhe / off / ""（未配置） */
    private String provider;

    /** 当前值来源：DB（管理端配置）/ ENV（环境变量兜底）/ NONE */
    private String source;

    /** 环境变量里注入的默认 provider（只读参考） */
    private String envProvider;

    /** 可选项：aliyun_auth / juhe / off */
    private List<String> supported;

    /** 阿里云短信认证密钥/签名/模板是否齐备 */
    private Boolean aliyunReady;

    /** 聚合数据密钥/模板是否齐备 */
    private Boolean juheReady;

    /** 阿里云赠送签名名（非敏感） */
    private String aliyunSignName;

    /** 阿里云赠送模板 CODE（非敏感） */
    private String aliyunTemplateCode;

    /** 聚合模板 ID（非敏感） */
    private String juheTplId;
}
