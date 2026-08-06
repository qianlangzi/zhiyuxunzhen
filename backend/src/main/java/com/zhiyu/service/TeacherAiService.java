package com.zhiyu.service;

import com.zhiyu.service.dto.CaseDraftDTO;

import java.util.Map;

/**
 * 教师端 AI 辅助服务（PRD 4.1 / 9.3 扩展）
 *
 * 提供 6 个 AI 辅助能力，最终返回 AI 中台的结构化结果（Map），
 * AI 不可用时返回 null，由 Controller 统一输出友好提示。
 */
public interface TeacherAiService {

    /**
     * 1. AI 生成 SP 病例草稿（RAG 教材锚点）
     */
    Map<String, Object> generateCaseDraft(CaseDraftDTO req);

    /**
     * 2. AI 班级学情洞察（基于真实聚合统计，LLM 只归纳）
     */
    Map<String, Object> classInsight(Long teacherId);

    /**
     * 3. AI 复核辅助（复核建议 + 评语草稿）
     */
    Map<String, Object> reviewAssist(Long instanceId);

    /**
     * 4. AI 推荐作业病例（基于班级薄弱点 + 病例库）
     */
    Map<String, Object> recommendCases(Long classId);

    /**
     * 5. AI 病例质检
     */
    Map<String, Object> qualityCheck(Long caseId);

    /**
     * 6. AI 自动生成练习题
     */
    Map<String, Object> practiceQuestions(Long caseId);
}