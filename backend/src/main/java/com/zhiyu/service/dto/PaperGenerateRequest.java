package com.zhiyu.service.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import lombok.Data;

import java.util.List;

/**
 * AI 组卷请求（P2-4 学生自测卷）
 * 学生按「题型 + 科室 + 知识点 + 难度偏好 + 题量」生成个性化自测卷。
 * 前端选定的题型 / 科室 / 知识点作为硬过滤条件，真正参与组卷筛选（2026-09-04 修复：
 * 此前这些字段被后端忽略，学生配置不生效，只按系统薄弱点组卷）。
 */
@Data
public class PaperGenerateRequest {

    /** 目标题量 1~50，默认 10（与前端滑块上限对齐） */
    @Min(value = 1, message = "题量至少为1")
    @Max(value = 50, message = "题量最多为50")
    private Integer count = 10;

    /** 难度偏好 1简单 2标准 3困难，空=不限 */
    @Min(value = 1, message = "难度取值错误")
    @Max(value = 3, message = "难度取值错误")
    private Integer difficulty;

    /** 指定的题型（单选/判断/多选/填空等题型的取值），空=不限 */
    private List<String> questionTypes;

    /** 指定的科室/学科，空=不限 */
    private List<String> departments;

    /** 指定的知识点，空=不限；同时作为组卷时薄弱点优先权重 */
    private List<String> knowledgeTags;

    /** 指定薄弱知识点（兼容旧参数，不传时取系统统计的薄弱点） */
    private List<String> focusTags;
}
