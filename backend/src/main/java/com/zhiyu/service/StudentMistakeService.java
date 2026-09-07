package com.zhiyu.service;

import com.zhiyu.common.result.PageResult;
import com.zhiyu.vo.MistakeVO;

import java.util.Map;

/**
 * 学生错题本服务（PRD 4.11）
 */
public interface StudentMistakeService {

    /**
     * 我的错题本列表（分页，支持类型筛选）
     */
    PageResult<MistakeVO> myMistakes(Integer pageNum, Integer pageSize, String mistakeType);

    /**
     * 单条错题 AI 归因（缓存命中直接返回；未命中调用 AI 并持久化缓存；
     * AI 不可用时返回 status=DEGRADED 的可重试提示）
     */
    Map<String, Object> analyzeMistake(Long mistakeId);

    /**
     * 回写错题复习状态（人工标记，闭环出口）。
     *
     * @param mistakeId    错题 id
     * @param resolvedStatus 0未复习 1已复习 2已掌握
     */
    void markResolved(Long mistakeId, Integer resolvedStatus);

    /**
     * 生成并缓存归因（内部调用，不依赖 UserContext）。
     *
     * <p>供错题入库后的异步预生成使用：异步线程里 UserContext 为空，
     * 因此 studentId 必须由调用方显式传入。执行失败只记日志，不向上抛，
     * 避免影响主链路（学生仍可手动点击触发归因）。
     *
     * @param mistakeId 错题 id
     * @param studentId 归属学生 id（用于校验归属）
     */
    void generateAnalysis(Long mistakeId, Long studentId);

    /**
     * 基于错题归因生成巩固练习（练同类题）。
     *
     * <p>用「错题知识点 + AI 归因推荐标签」作为组卷焦点，复用现有 AI 组卷能力，
     * 把归因结论真正变成下一次练习，打通「归因 → 巩固 → 再判掌握」闭环。
     *
     * @param mistakeId 错题 id
     * @param count     题量
     * @return 与自测卷同构的结果（paperTitle/rationale/source/status/questions）
     */
    Map<String, Object> generateDrill(Long mistakeId, int count);
}
