package com.zhiyu.vo;

import lombok.Builder;
import lombok.Data;

import java.util.List;

/**
 * 全局智能检索结果 VO（教材 + 基础题 + 病例）
 */
@Data
@Builder
public class SearchResultVO {
    private List<TextbookVO> textbooks;
    private List<PracticeQuestionVO> questions;
    private List<CaseMarketListVO> cases;
}