package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@Builder
public class AiPromptVO {
    private Long id;
    private String name;
    private String version;
    private String title;
    private String description;
    private String content;
    private Boolean isActive;
    private Integer status;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}