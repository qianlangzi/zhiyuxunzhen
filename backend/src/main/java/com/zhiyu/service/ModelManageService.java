package com.zhiyu.service;

import com.zhiyu.common.param.PageParam;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.dto.AiModelDTO;
import com.zhiyu.vo.ActiveModelVO;
import com.zhiyu.vo.AiModelVO;

import java.util.Map;

/**
 * AI 模型管理服务（PRD 4.16 扩展 · 模型管理）
 *
 * 参照 ccswitch 供应商管理模式：同一能力维度可配置多个供应商，管理端一键切换生效。
 * AI 中台通过内部接口 /api/internal/model/active 热读取「启用且激活」的模型配置，
 * 使教师端/学生端的 AI 功能即时切换指定模型（无需重启服务）。
 */
public interface ModelManageService {

    /**
     * 模型分页查询（可按能力维度过滤）
     */
    PageResult<AiModelVO> page(PageParam param, String capability);

    /**
     * 新增模型
     */
    AiModelVO create(AiModelDTO dto);

    /**
     * 更新模型（apiKey 传空串=保留原密钥）
     */
    AiModelVO update(Long id, AiModelDTO dto);

    /**
     * 删除模型
     */
    void delete(Long id);

    /**
     * 切换激活：将指定模型设为当前能力下唯一激活项
     */
    void setActive(Long id);

    /**
     * 停用/启用切换
     */
    void toggleStatus(Long id);

    /**
     * 连通性测试（OpenAI 兼容），返回 ok/耗时/说明
     */
    Map<String, Object> testConnect(Long id);

    /**
     * 查询每个能力下「启用且激活」的模型真实配置（供 AI 中台内部接口使用）
     */
    Map<String, ActiveModelVO> activeConfigs();
}