package com.zhiyu.service.dto;

import lombok.Data;

/**
 * 个人资料更新请求
 */
@Data
public class ProfileUpdateDTO {
    private String nickname;
    private String studentNumber;
    private String major;
    private String grade;
    private String contact;
    private String avatarPath;
}