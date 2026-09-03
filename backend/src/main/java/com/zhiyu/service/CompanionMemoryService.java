package com.zhiyu.service;

import com.zhiyu.common.result.PageResult;
import com.zhiyu.entity.CompanionMemory;
import com.zhiyu.service.dto.internal.CompanionMemoriesSyncDTO;

import java.util.List;

/**
 * AI 学伴长期记忆服务（抽取式记忆：对话后 AI 抽取事实入库，对话前召回注入）
 * 仅学伴链路使用，区别于 SP（标准病人）。
 */
public interface CompanionMemoryService {

    /**
     * 学伴对话单次召回并注入 AI 上下文的记忆条数。
     * 与 AI 侧 companion_workflow._MEMORY_SHOW_MAX 对齐（展示上限 = 召回上限，
     * 避免召回过量在 AI 侧被静默丢弃），两端需同步调整。
     */
    int RECALL_LIMIT = 6;

    /**
     * 当前学生最近 limit 条记忆（时间正序，供组装学情上下文注入 AI）
     */
    List<CompanionMemory> recent(int limit);

    /**
     * 当前学生记忆分页（记忆管理页）
     */
    PageResult<CompanionMemory> page(int pageNum, int pageSize);

    /**
     * 删除当前学生一条记忆（逻辑删除）
     */
    void deleteOwned(Long id);

    /**
     * 清空当前学生全部记忆（逻辑删除）
     */
    void clearAll();

    /**
     * AI 内部回调：批量写入抽取的记忆（按 studentId，不做登录归属校验），返回实际写入条数
     */
    int saveFromAi(Long studentId, List<CompanionMemoriesSyncDTO.MemoryFact> facts);
}
