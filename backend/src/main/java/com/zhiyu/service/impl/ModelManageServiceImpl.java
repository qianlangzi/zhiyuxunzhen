package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.common.param.PageParam;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.entity.AiModel;
import com.zhiyu.mapper.AiModelMapper;
import com.zhiyu.service.AuditLogService;
import com.zhiyu.service.ModelManageService;
import com.zhiyu.service.dto.AiModelDTO;
import com.zhiyu.vo.ActiveModelVO;
import com.zhiyu.vo.AiModelVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;
import org.springframework.web.client.RestTemplate;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * AI 模型管理服务实现
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ModelManageServiceImpl implements ModelManageService {

    private final AiModelMapper aiModelMapper;
    private final AuditLogService auditLogService;
    private final ObjectMapper objectMapper;
    private final RestTemplate restTemplate;

    /** 支持的模型能力维度 */
    private static final Set<String> CAPABILITIES = Set.of("LLM", "VISION", "EMBEDDING", "EMBEDDING_MULTI");

    private static final String CAP_EMBEDDING_MULTI = "EMBEDDING_MULTI";

    private static final int DEFAULT_TIMEOUT = 30;

    // ==================== 查询 ====================

    @Override
    public PageResult<AiModelVO> page(PageParam param, String capability) {
        LambdaQueryWrapper<AiModel> wrapper = new LambdaQueryWrapper<>();
        if (StringUtils.hasText(capability)) {
            wrapper.eq(AiModel::getCapability, capability);
        }
        wrapper.orderByAsc(AiModel::getCapability)
                .orderByDesc(AiModel::getIsActive)
                .orderByDesc(AiModel::getId);

        Page<AiModel> page = aiModelMapper.selectPage(
                new Page<>(param.getPageNum(), param.getPageSize()), wrapper);

        List<AiModelVO> vos = page.getRecords().stream().map(this::toVO).toList();
        return PageResult.of(page, vos);
    }

    // ==================== 新增 / 更新 / 删除 ====================

    @Override
    @Transactional(rollbackFor = Exception.class)
    public AiModelVO create(AiModelDTO dto) {
        validate(dto);
        AiModel model = new AiModel();
        apply(model, dto);
        // 停用状态下的新模型不参与激活：先设置默认值
        model.setIsActive(false);
        if (model.getStatus() == null) {
            model.setStatus(1);
        }
        if (model.getTimeoutSeconds() == null) {
            model.setTimeoutSeconds(DEFAULT_TIMEOUT);
        }
        aiModelMapper.insert(model);
        auditLogService.record("ai_model_create", "ai_model", model.getId(), null, toAuditJson(model));
        log.info("AI 模型新增: id={} name={} capability={}", model.getId(), model.getName(), model.getCapability());
        return toVO(aiModelMapper.selectById(model.getId()));
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public AiModelVO update(Long id, AiModelDTO dto) {
        AiModel existing = require(id);
        validate(dto);
        String beforeJson = toAuditJson(existing);

        // 更新时 apiKey 传空串/Null/脱敏占位值（*** 前缀）表示保留原密钥（前端回显的是脱敏值）
        boolean keepKey = !StringUtils.hasText(dto.getApiKey())
                || dto.getApiKey().startsWith("****");
        String originalKey = existing.getApiKey();

        apply(existing, dto);
        if (keepKey) {
            existing.setApiKey(originalKey);
        }
        if (existing.getTimeoutSeconds() == null) {
            existing.setTimeoutSeconds(DEFAULT_TIMEOUT);
        }
        aiModelMapper.updateById(existing);

        String afterJson = toAuditJson(aiModelMapper.selectById(id));
        auditLogService.record("ai_model_update", "ai_model", id, beforeJson, afterJson);
        log.info("AI 模型更新: id={} name={}", id, existing.getName());
        return toVO(aiModelMapper.selectById(id));
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void delete(Long id) {
        require(id);
        aiModelMapper.deleteById(id);
        auditLogService.record("ai_model_delete", "ai_model", id, null, null);
        log.info("AI 模型删除: id={}", id);
    }

    // ==================== 激活 / 停用 ====================

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void setActive(Long id) {
        AiModel model = require(id);
        if (model.getStatus() != null && model.getStatus() != 1) {
            throw new BizException(ResultCode.BAD_REQUEST, "停用的模型不能设为激活，请先启用");
        }
        if (!StringUtils.hasText(model.getApiKey())) {
            throw new BizException(ResultCode.BAD_REQUEST, "该模型尚未配置 API Key，请先填写密钥再激活");
        }
        String capability = model.getCapability();

        String beforeJson = toAuditJson(model);

        // 同一能力下先全部置为非激活，再激活当前项
        aiModelMapper.update(
                new AiModel(),
                new LambdaQueryWrapper<AiModel>()
                        .eq(AiModel::getCapability, capability)
                        .eq(AiModel::getIsActive, true));
        model.setIsActive(true);
        aiModelMapper.updateById(model);

        String afterJson = toAuditJson(model);
        auditLogService.record("ai_model_activate", "ai_model", id, beforeJson, afterJson);
        log.info("AI 模型激活: id={} capability={} model={}", id, capability, model.getModel());
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void toggleStatus(Long id) {
        AiModel model = require(id);
        String beforeJson = toAuditJson(model);
        int newStatus = (model.getStatus() != null && model.getStatus() == 1) ? 0 : 1;
        model.setStatus(newStatus);
        // 停用时若为当前激活项，一并取消激活，避免向下游暴露失效配置
        if (newStatus == 0 && Boolean.TRUE.equals(model.getIsActive())) {
            model.setIsActive(false);
        }
        aiModelMapper.updateById(model);
        String afterJson = toAuditJson(model);
        auditLogService.record("ai_model_toggle", "ai_model", id, beforeJson, afterJson);
        log.info("AI 模型停用/启用: id={} status={}", id, newStatus);
    }

    // ==================== 连通性测试 ====================

    @Override
    public Map<String, Object> testConnect(Long id) {
        AiModel model = require(id);
        Map<String, Object> result = new LinkedHashMap<>();
        long start = System.currentTimeMillis();
        try {
            if (CAP_EMBEDDING_MULTI.equals(model.getCapability())) {
                result.put("ok", false);
                result.put("message", "多模态向量模型（DashScope 专属协议）暂不支持一键连通测试");
                return result;
            }
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.setBearerAuth(StringUtils.hasText(model.getApiKey()) ? model.getApiKey() : "");
            Map<String, Object> body = new LinkedHashMap<>();
            body.put("model", model.getModel());

            Object respData;
            if ("EMBEDDING".equals(model.getCapability())) {
                body.put("input", "连通性测试");
                respData = postRaw(model.getBaseUrl() + "/embeddings", headers, body);
            } else {
                body.put("messages", List.of(Map.of("role", "user", "content", "连通性测试")));
                body.put("max_tokens", 1);
                respData = postRaw(model.getBaseUrl() + "/chat/completions", headers, body);
            }
            result.put("ok", true);
            result.put("latencyMs", System.currentTimeMillis() - start);
            result.put("message", "连通正常");
            result.put("raw", respData);
        } catch (Exception e) {
            result.put("ok", false);
            result.put("latencyMs", System.currentTimeMillis() - start);
            result.put("message", "连接失败：" + e.getMessage());
        }
        return result;
    }

    private Object postRaw(String url, HttpHeaders headers, Map<String, Object> body) {
        ResponseEntity<String> resp = restTemplate.postForEntity(
                url, new HttpEntity<>(body, headers), String.class);
        return resp.getBody();
    }

    // ==================== 内部：活跃模型配置 ====================

    @Override
    public Map<String, ActiveModelVO> activeConfigs() {
        List<AiModel> list = aiModelMapper.selectList(
                new LambdaQueryWrapper<AiModel>()
                        .eq(AiModel::getStatus, 1)
                        .eq(AiModel::getIsActive, true));
        Map<String, ActiveModelVO> map = new LinkedHashMap<>();
        for (AiModel m : list) {
            map.put(m.getCapability(), toActiveVO(m));
        }
        return map;
    }

    // ==================== 私有工具 ====================

    private AiModel require(Long id) {
        AiModel model = aiModelMapper.selectById(id);
        if (model == null) {
            throw new BizException(ResultCode.NOT_FOUND, "模型不存在");
        }
        return model;
    }

    private void validate(AiModelDTO dto) {
        if (!CAPABILITIES.contains(dto.getCapability())) {
            throw new BizException(ResultCode.BAD_REQUEST,
                    "能力类型不合法，仅支持 LLM / VISION / EMBEDDING / EMBEDDING_MULTI");
        }
    }

    private void apply(AiModel model, AiModelDTO dto) {
        model.setName(dto.getName());
        model.setProvider(dto.getProvider());
        model.setCapability(dto.getCapability());
        model.setBaseUrl(dto.getBaseUrl());
        model.setApiKey(dto.getApiKey());
        model.setModel(dto.getModel());
        model.setDimension(dto.getDimension());
        model.setTimeoutSeconds(dto.getTimeoutSeconds());
        model.setMaxTokens(dto.getMaxTokens());
        model.setTemperature(dto.getTemperature());
        model.setStatus(dto.getStatus());
        model.setDescription(dto.getDescription());
    }

    private AiModelVO toVO(AiModel m) {
        if (m == null) {
            return null;
        }
        return AiModelVO.builder()
                .id(m.getId())
                .name(m.getName())
                .provider(m.getProvider())
                .capability(m.getCapability())
                .baseUrl(m.getBaseUrl())
                .apiKey(mask(m.getApiKey()))
                .hasApiKey(StringUtils.hasText(m.getApiKey()))
                .model(m.getModel())
                .dimension(m.getDimension())
                .timeoutSeconds(m.getTimeoutSeconds())
                .maxTokens(m.getMaxTokens())
                .temperature(m.getTemperature())
                .isActive(Boolean.TRUE.equals(m.getIsActive()))
                .status(m.getStatus())
                .description(m.getDescription())
                .createdAt(m.getCreatedAt())
                .updatedAt(m.getUpdatedAt())
                .build();
    }

    private ActiveModelVO toActiveVO(AiModel m) {
        return ActiveModelVO.builder()
                .id(m.getId())
                .capability(m.getCapability())
                .baseUrl(m.getBaseUrl())
                .apiKey(m.getApiKey())
                .model(m.getModel())
                .dimension(m.getDimension())
                .timeoutSeconds(m.getTimeoutSeconds())
                .maxTokens(m.getMaxTokens())
                .temperature(m.getTemperature())
                .build();
    }

    /** 密钥脱敏：保留末 4 位 */
    private String mask(String key) {
        if (!StringUtils.hasText(key)) {
            return null;
        }
        if (key.length() <= 4) {
            return "****";
        }
        return "****" + key.substring(key.length() - 4);
    }

    /** 审计 JSON：apiKey 一律脱敏，避免密钥泄露进审计日志 */
    private String toAuditJson(AiModel m) {
        try {
            Map<String, Object> map = new HashMap<>();
            map.put("id", m.getId());
            map.put("name", m.getName());
            map.put("provider", m.getProvider());
            map.put("capability", m.getCapability());
            map.put("baseUrl", m.getBaseUrl());
            map.put("apiKey", mask(m.getApiKey()));
            map.put("model", m.getModel());
            map.put("dimension", m.getDimension());
            map.put("timeoutSeconds", m.getTimeoutSeconds());
            map.put("maxTokens", m.getMaxTokens());
            map.put("temperature", m.getTemperature());
            map.put("isActive", m.getIsActive());
            map.put("status", m.getStatus());
            return objectMapper.writeValueAsString(map);
        } catch (Exception e) {
            return "{}";
        }
    }
}