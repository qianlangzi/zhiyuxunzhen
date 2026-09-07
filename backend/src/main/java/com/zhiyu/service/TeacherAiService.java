package com.zhiyu.service;

import com.zhiyu.service.dto.CaseDraftDTO;

import java.util.List;
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
    Map<String, Object> classInsight(Long teacherId, Long classId);

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

    /**
     * 病例素材智能推荐：AI 建议教师应准备的多模态材料清单（问诊配套）。
     */
    Map<String, Object> materialAdvice(Long caseId);

    /**
     * 7. 生成并持久化学情诊断报告（P1-1）
     * 基于真实聚合统计 + AI 归纳生成一份班级学情报告并落库；
     * classId 为空表示「全体学生」粒度；AI 不可用时降级为纯统计快照。
     */
    Map<String, Object> generateClassReport(Long classId);

    /**
     * 历史学情诊断报告列表（当前教师所有报告，倒序）
     */
    List<Map<String, Object>> listDiagnosisReports();

    /**
     * 学情诊断报告详情
     */
    Map<String, Object> getDiagnosisReport(Long id);

    /**
     * 删除学情诊断报告（仅本人）
     */
    void deleteDiagnosisReport(Long id);
}