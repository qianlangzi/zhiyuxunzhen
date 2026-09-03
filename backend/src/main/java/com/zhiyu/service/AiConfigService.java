package com.zhiyu.service;

import com.zhiyu.common.param.PageParam;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.dto.AiAgentDTO;
import com.zhiyu.service.dto.AiPromptDTO;
import com.zhiyu.service.dto.AiRuntimeConfigDTO;
import com.zhiyu.vo.ActiveAgentVO;
import com.zhiyu.vo.ActivePromptVO;
import com.zhiyu.vo.AiAgentVO;
import com.zhiyu.vo.AiPromptVO;
import com.zhiyu.vo.AiRuntimeConfigVO;
import com.zhiyu.vo.ModelEventLogVO;

import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * AI 配置中心服务（提示词 · Agent 元参数 · RAG 运行参数 热更新）
 */
public interface AiConfigService {

    // ==================== 提示词 ====================

    PageResult<AiPromptVO> promptPage(PageParam param, String name);

    AiPromptVO promptCreate(AiPromptDTO dto);

    AiPromptVO promptUpdate(Long id, AiPromptDTO dto);

    void promptDelete(Long id);

    void promptSetActive(Long id);

    void promptToggle(Long id);

    /** 内网：各 name「启用且激活」的提示词，供 AI 中台热读取 */
    Map<String, ActivePromptVO> activePrompts();

    // ==================== Agent ====================

    PageResult<AiAgentVO> agentPage(PageParam param, String code);

    AiAgentVO agentCreate(AiAgentDTO dto);

    AiAgentVO agentUpdate(Long id, AiAgentDTO dto);

    void agentDelete(Long id);

    void agentSetActive(Long id);

    void agentToggle(Long id);

    /** 内网：各 code「启用且激活」的 Agent 元参数，供 AI 中台热读取 */
    Map<String, ActiveAgentVO> activeAgents();

    // ==================== RAG 运行参数 ====================

    PageResult<AiRuntimeConfigVO> runtimePage(PageParam param, String configKey);

    /** 键值型 upsert（按 config_key 唯一） */
    AiRuntimeConfigVO runtimeSave(AiRuntimeConfigDTO dto);

    void runtimeDelete(Long id);

    /** 内网：所有参与下发的键值（is_active=1），供 AI 中台热覆盖运行期参数 */
    Map<String, String> activeRuntimeConfigs();

    // ==================== AI 中台运行态 / 基线（管理端观测面） ====================

    /** AI 中台运行态快照（经 AiPlatformClient 代理）；AI 不可用时返回 null */
    Map<String, Object> aiRuntimeStatus();

    Map<String, Object> refreshAiRuntime();

    /** AI 中台内置提示词基线；AI 不可用时返回 null */
    Map<String, Object> promptBaseline();

    /** AI 中台内置 Agent 元参数基线；AI 不可用时返回 null */
    Map<String, Object> agentBaseline();

    /** 将 AI 中台内置提示词基线导入数据库（缺失才导入，已存在跳过）。names 为空表示导入全部 */
    int promptImportBaseline(Set<String> names);

    /** 将 AI 中台内置 Agent 元参数基线导入数据库（缺失才导入，已存在跳过）。codes 为空表示导入全部 */
    int agentImportBaseline(Set<String> codes);

    /** 最近 N 条模型运行事件（AI 中台「最近模型事件」视图；limit 默认 20，上限 50） */
    List<ModelEventLogVO> recentModelEvents(int limit);
}
