-- ============================================================
-- V26: 错题 AI 归因缓存列（P0-2）
-- ------------------------------------------------------------
-- student_mistakes.ai_analysis_json 持久化错题归因 Agent 的结构化输出
-- （rootCause / explanation / recommendedTags / practiceHint / source / status），
-- 避免每次进入错题本都重复调用 AI，实现「分析一次、长期复用」。
-- 由后端 /api/v1/student/mistakes/{id}/analyze 写入。
-- ============================================================

ALTER TABLE student_mistakes
    ADD COLUMN ai_analysis_json JSON NULL COMMENT '错题 AI 归因结果 JSON（rootCause/explanation/recommendedTags/practiceHint/source/status）' AFTER evidence_json;
