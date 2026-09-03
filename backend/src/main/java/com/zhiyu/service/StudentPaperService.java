package com.zhiyu.service;

import com.zhiyu.service.dto.PaperGenerateRequest;

import java.util.Map;

/**
 * 学生端 AI 组卷服务（P2-4 学生自测卷）
 *
 * 组卷闭环：取学生薄弱知识点 → 抽取审核通过的题库候选 → 调用 AI 中台选题组卷
 * （AI 只做选题不生成题目，防幻觉）→ 按选中 ID 解析题目返回。
 * AI 不可用时回退规则组卷（薄弱点优先 + 难度进阶），保证一键自测始终可用。
 */
public interface StudentPaperService {

    /**
     * 生成个性化自测卷
     *
     * @return {
     *   paperTitle, rationale, weakTags, source, status,
     *   questions: [PracticeQuestionVO...]
     * }
     */
    Map<String, Object> generate(PaperGenerateRequest req);

    /**
     * 提交异步组卷任务（候选组装 + AI 选题 + 题目解析在后台线程执行）
     * 立即返回 {taskId, status=PENDING}，客户端轮询 getTask。
     */
    Map<String, Object> submitTask(PaperGenerateRequest req);

    /**
     * 查询组卷任务结果
     *
     * @return {taskId, status(PENDING/RUNNING/SUCCEEDED/FAILED_RETRYABLE/FAILED_FINAL),
     *          errorMessage, paper({paperTitle, rationale, weakTags, source, questions:[PracticeQuestionVO...]})}
     */
    Map<String, Object> getTask(String taskId);
}
