package com.zhiyu.service.dto;

import lombok.Data;

/**
 * 向导式备课对话请求（教师回答本轮问题）
 */
@Data
public class LessonGuideDTO {

    /** 用户对本轮问题的回答/补充（支持语音转文字后的文本） */
    private String userReply;
}
