-- V48: practice_question 组合索引（2026-09-09 性能修复）
--
-- 背景：题库已到 5.6 万行，且几乎全部 status=1 / admin_audit_status=2。
-- 旧的单列索引（idx_status / idx_department / idx_knowledge_tag）无法同时覆盖
-- 「状态过滤 + 科室/知识点分组」，导致：
--   1. /questions/departments、/questions/knowledge-tags 每次全表 GROUP BY（实测 126/142ms）；
--   2. /questions 分页排序 filesort；
--   3. /questions/stats 的两次全表计数（已改聚合 SQL，本索引使其走覆盖索引）。
-- 两个组合索引均为 (等值过滤列..., 分组/排序列) 结构，等值条件在前时
-- GROUP BY 可走 index for group-by / loose index scan，免回表。
-- 旧单列索引保留（其他查询路径仍引用），不做 DROP。

ALTER TABLE practice_question
    ADD INDEX idx_pq_status_audit_dept (status, admin_audit_status, department),
    ADD INDEX idx_pq_status_audit_tag (status, admin_audit_status, knowledge_tag);
