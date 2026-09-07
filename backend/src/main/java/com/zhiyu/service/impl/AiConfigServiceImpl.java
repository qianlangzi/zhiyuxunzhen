package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.zhiyu.client.AiPlatformClient;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.param.PageParam;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.entity.AiAgent;
import com.zhiyu.entity.AiPrompt;
import com.zhiyu.entity.AiRuntimeConfig;
import com.zhiyu.entity.ModelEventLog;
import com.zhiyu.mapper.AiAgentMapper;
import com.zhiyu.mapper.AiPromptMapper;
import com.zhiyu.mapper.AiRuntimeConfigMapper;
import com.zhiyu.mapper.ModelEventLogMapper;
import com.zhiyu.service.AiConfigService;
import com.zhiyu.service.AuditLogService;
import com.zhiyu.service.dto.AiAgentDTO;
import com.zhiyu.service.dto.AiPromptDTO;
import com.zhiyu.service.dto.AiRuntimeConfigDTO;
import com.zhiyu.vo.ActiveAgentVO;
import com.zhiyu.vo.ActivePromptVO;
import com.zhiyu.vo.AiAgentVO;
import com.zhiyu.vo.AiPromptVO;
import com.zhiyu.vo.AiRuntimeConfigVO;
import com.zhiyu.vo.ModelEventLogVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.math.BigDecimal;

/**
 * AI 配置中心服务实现（提示词 · Agent 元参数 · RAG 运行参数）
 *
 * 与 ModelManageService 同构：每逻辑键（name/code）下至多一个 is_active=1，
 * status 控制启停；AI 中台周期调用内网 active 接口热拉取最新值。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AiConfigServiceImpl implements AiConfigService {

    private final AiPromptMapper aiPromptMapper;
    private final AiAgentMapper aiAgentMapper;
    private final AiRuntimeConfigMapper aiRuntimeConfigMapper;
    private final AuditLogService auditLogService;
    private final AiPlatformClient aiPlatformClient;
    private final ModelEventLogMapper modelEventLogMapper;

    /** 运行参数类型黑名单，防止注入非法控件类型 */
    private static final Set<String> RUNTIME_TYPES = Set.of("number", "float", "switch", "text");

    // ==================== 提示词 ====================

    @Override
    public PageResult<AiPromptVO> promptPage(PageParam param, String name) {
        LambdaQueryWrapper<AiPrompt> wrapper = new LambdaQueryWrapper<>();
        if (StringUtils.hasText(name)) {
            wrapper.eq(AiPrompt::getName, name);
        }
        wrapper.orderByAsc(AiPrompt::getName)
                .orderByDesc(AiPrompt::getIsActive)
                .orderByDesc(AiPrompt::getId);
        Page<AiPrompt> page = aiPromptMapper.selectPage(
                new Page<>(param.getPageNum(), param.getPageSize()), wrapper);
        List<AiPromptVO> vos = page.getRecords().stream().map(this::toPromptVO).toList();
        return PageResult.of(page, vos);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public AiPromptVO promptCreate(AiPromptDTO dto) {
        String name = dto.getName().trim();
        // 一个 name 下可有多版本，但禁止同版本重复
        checkDuplicatePrompt(name, null, dto.getVersion());
        AiPrompt p = new AiPrompt();
        p.setName(name);
        apply(p, dto);
        p.setIsActive(false);
        if (p.getStatus() == null) {
            p.setStatus(1);
        }
        if (!StringUtils.hasText(p.getVersion())) {
            p.setVersion("v1");
        }
        aiPromptMapper.insert(p);
        auditLogService.record("ai_prompt_create", "ai_prompt", p.getId(), null, p.getName() + "/" + p.getVersion());
        log.info("提示词新增: id={} name={} version={}", p.getId(), p.getName(), p.getVersion());
        return toPromptVO(aiPromptMapper.selectById(p.getId()));
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public AiPromptVO promptUpdate(Long id, AiPromptDTO dto) {
        AiPrompt existing = requirePrompt(id);
        String name = dto.getName().trim();
        checkDuplicatePrompt(name, id, dto.getVersion());
        String before = existing.getName() + "/" + existing.getVersion();
        apply(existing, dto);
        existing.setName(name);
        if (!StringUtils.hasText(existing.getVersion())) {
            existing.setVersion("v1");
        }
        aiPromptMapper.updateById(existing);
        String after = existing.getName() + "/" + existing.getVersion();
        auditLogService.record("ai_prompt_update", "ai_prompt", id, before, after);
        log.info("提示词更新: id={} name={} version={}", id, name, existing.getVersion());
        return toPromptVO(aiPromptMapper.selectById(id));
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void promptDelete(Long id) {
        requirePrompt(id);
        aiPromptMapper.deleteById(id);
        auditLogService.record("ai_prompt_delete", "ai_prompt", id, null, null);
        log.info("提示词删除: id={}", id);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void promptSetActive(Long id) {
        AiPrompt p = requirePrompt(id);
        if (p.getStatus() != null && p.getStatus() != 1) {
            throw new BizException(ResultCode.BAD_REQUEST, "停用的提示词不能设为激活，请先启用");
        }
        String name = p.getName();
        String before = name + "/" + p.getVersion();
        aiPromptMapper.update(
                new AiPrompt(),
                new LambdaQueryWrapper<AiPrompt>()
                        .eq(AiPrompt::getName, name)
                        .eq(AiPrompt::getIsActive, true));
        p.setIsActive(true);
        aiPromptMapper.updateById(p);
        auditLogService.record("ai_prompt_activate", "ai_prompt", id, before, name + "/" + p.getVersion());
        log.info("提示词激活: id={} name={} version={}", id, name, p.getVersion());
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void promptToggle(Long id) {
        AiPrompt p = requirePrompt(id);
        int newStatus = (p.getStatus() != null && p.getStatus() == 1) ? 0 : 1;
        p.setStatus(newStatus);
        if (newStatus == 0 && Boolean.TRUE.equals(p.getIsActive())) {
            p.setIsActive(false);
        }
        aiPromptMapper.updateById(p);
        auditLogService.record("ai_prompt_toggle", "ai_prompt", id, null, String.valueOf(newStatus));
        log.info("提示词停用/启用: id={} status={}", id, newStatus);
    }

    @Override
    public Map<String, ActivePromptVO> activePrompts() {
        List<AiPrompt> list = aiPromptMapper.selectList(
                new LambdaQueryWrapper<AiPrompt>()
                        .eq(AiPrompt::getStatus, 1)
                        .eq(AiPrompt::getIsActive, true));
        Map<String, ActivePromptVO> map = new LinkedHashMap<>();
        for (AiPrompt p : list) {
            map.put(p.getName(), ActivePromptVO.builder()
                    .id(p.getId()).name(p.getName()).version(p.getVersion()).content(p.getContent()).build());
        }
        return map;
    }

    // ==================== Agent ====================

    @Override
    public PageResult<AiAgentVO> agentPage(PageParam param, String code) {
        LambdaQueryWrapper<AiAgent> wrapper = new LambdaQueryWrapper<>();
        if (StringUtils.hasText(code)) {
            wrapper.eq(AiAgent::getCode, code);
        }
        wrapper.orderByAsc(AiAgent::getCode)
                .orderByDesc(AiAgent::getIsActive)
                .orderByDesc(AiAgent::getId);
        Page<AiAgent> page = aiAgentMapper.selectPage(
                new Page<>(param.getPageNum(), param.getPageSize()), wrapper);
        List<AiAgentVO> vos = page.getRecords().stream().map(this::toAgentVO).toList();
        return PageResult.of(page, vos);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public AiAgentVO agentCreate(AiAgentDTO dto) {
        String code = dto.getCode().trim();
        checkDuplicateAgent(code, null, dto.getName());
        AiAgent a = new AiAgent();
        a.setCode(code);
        apply(a, dto);
        a.setIsActive(false);
        if (a.getStatus() == null) {
            a.setStatus(1);
        }
        if (!StringUtils.hasText(a.getPromptName())) {
            a.setPromptName(code);
        }
        aiAgentMapper.insert(a);
        auditLogService.record("ai_agent_create", "ai_agent", a.getId(), null, code);
        log.info("Agent 新增: id={} code={}", a.getId(), code);
        return toAgentVO(aiAgentMapper.selectById(a.getId()));
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public AiAgentVO agentUpdate(Long id, AiAgentDTO dto) {
        AiAgent existing = requireAgent(id);
        String code = dto.getCode().trim();
        checkDuplicateAgent(code, id, dto.getName());
        apply(existing, dto);
        if (!StringUtils.hasText(existing.getPromptName())) {
            existing.setPromptName(code);
        }
        aiAgentMapper.updateById(existing);
        auditLogService.record("ai_agent_update", "ai_agent", id, null, code);
        log.info("Agent 更新: id={} code={}", id, code);
        return toAgentVO(aiAgentMapper.selectById(id));
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void agentDelete(Long id) {
        requireAgent(id);
        aiAgentMapper.deleteById(id);
        auditLogService.record("ai_agent_delete", "ai_agent", id, null, null);
        log.info("Agent 删除: id={}", id);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void agentSetActive(Long id) {
        AiAgent a = requireAgent(id);
        if (a.getStatus() != null && a.getStatus() != 1) {
            throw new BizException(ResultCode.BAD_REQUEST, "停用的 Agent 不能设为激活，请先启用");
        }
        String code = a.getCode();
        aiAgentMapper.update(
                new AiAgent(),
                new LambdaQueryWrapper<AiAgent>()
                        .eq(AiAgent::getCode, code)
                        .eq(AiAgent::getIsActive, true));
        a.setIsActive(true);
        aiAgentMapper.updateById(a);
        auditLogService.record("ai_agent_activate", "ai_agent", id, null, code);
        log.info("Agent 激活: id={} code={}", id, code);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void agentToggle(Long id) {
        AiAgent a = requireAgent(id);
        int newStatus = (a.getStatus() != null && a.getStatus() == 1) ? 0 : 1;
        a.setStatus(newStatus);
        if (newStatus == 0 && Boolean.TRUE.equals(a.getIsActive())) {
            a.setIsActive(false);
        }
        aiAgentMapper.updateById(a);
        auditLogService.record("ai_agent_toggle", "ai_agent", id, null, String.valueOf(newStatus));
        log.info("Agent 停用/启用: id={} status={}", id, newStatus);
    }

    @Override
    public Map<String, ActiveAgentVO> activeAgents() {
        List<AiAgent> list = aiAgentMapper.selectList(
                new LambdaQueryWrapper<AiAgent>()
                        .eq(AiAgent::getStatus, 1)
                        .eq(AiAgent::getIsActive, true));
        Map<String, ActiveAgentVO> map = new LinkedHashMap<>();
        for (AiAgent a : list) {
            map.put(a.getCode(), ActiveAgentVO.builder()
                    .id(a.getId()).code(a.getCode()).name(a.getName())
                    .promptName(a.getPromptName()).promptOverride(a.getPromptOverride())
                    .temperature(a.getTemperature()).maxTokens(a.getMaxTokens())
                    .toolsConfig(a.getToolsConfig())
                    .strategy(a.getStrategy()).model(a.getModel()).maxIterations(a.getMaxIterations())
                    .enabled(a.getStatus() != null && a.getStatus() == 1).build());
        }
        return map;
    }

    // ==================== RAG 运行参数 ====================

    @Override
    public PageResult<AiRuntimeConfigVO> runtimePage(PageParam param, String configKey) {
        LambdaQueryWrapper<AiRuntimeConfig> wrapper = new LambdaQueryWrapper<>();
        if (StringUtils.hasText(configKey)) {
            wrapper.like(AiRuntimeConfig::getConfigKey, configKey);
        }
        wrapper.orderByAsc(AiRuntimeConfig::getConfigKey);
        Page<AiRuntimeConfig> page = aiRuntimeConfigMapper.selectPage(
                new Page<>(param.getPageNum(), param.getPageSize()), wrapper);
        List<AiRuntimeConfigVO> vos = page.getRecords().stream().map(this::toRuntimeVO).toList();
        return PageResult.of(page, vos);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public AiRuntimeConfigVO runtimeSave(AiRuntimeConfigDTO dto) {
        String key = dto.getConfigKey().trim();
        String type = StringUtils.hasText(dto.getConfigType()) ? dto.getConfigType() : "number";
        if (!StringUtils.hasText(dto.getValue())) {
            throw new BizException(ResultCode.BAD_REQUEST, "配置值不能为空");
        }
        if (!RUNTIME_TYPES.contains(type)) {
            throw new BizException(ResultCode.BAD_REQUEST, "配置类型不合法：" + type);
        }
        if ("switch".equals(type) && !isBoolean(dto.getValue())) {
            throw new BizException(ResultCode.BAD_REQUEST, "开关类型值只能为 true/false");
        }
        if (("number".equals(type) || "float".equals(type)) && !isNumeric(dto.getValue())) {
            throw new BizException(ResultCode.BAD_REQUEST, "数字类型值必须为数字");
        }

        AiRuntimeConfig existing = aiRuntimeConfigMapper.selectOne(
                new LambdaQueryWrapper<AiRuntimeConfig>().eq(AiRuntimeConfig::getConfigKey, key));
        if (existing == null) {
            existing = new AiRuntimeConfig();
            existing.setConfigKey(key);
            existing.setIsActive(true);
        }
        String before = existing.getValue();
        apply(existing, dto);
        if (existing.getIsActive() == null) {
            existing.setIsActive(true);
        }
        if (existing.getId() == null) {
            aiRuntimeConfigMapper.insert(existing);
        } else {
            aiRuntimeConfigMapper.updateById(existing);
        }
        auditLogService.record("ai_runtime_config_save", "ai_runtime_config",
                existing.getId(), before, existing.getValue());
        log.info("RAG 运行参数保存: key={} value={}", key, existing.getValue());
        return toRuntimeVO(aiRuntimeConfigMapper.selectById(existing.getId()));
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void runtimeDelete(Long id) {
        requireRuntime(id);
        aiRuntimeConfigMapper.deleteById(id);
        auditLogService.record("ai_runtime_config_delete", "ai_runtime_config", id, null, null);
        log.info("RAG 运行参数删除: id={}", id);
    }

    @Override
    public Map<String, String> activeRuntimeConfigs() {
        List<AiRuntimeConfig> list = aiRuntimeConfigMapper.selectList(
                new LambdaQueryWrapper<AiRuntimeConfig>()
                        .eq(AiRuntimeConfig::getIsActive, true));
        Map<String, String> map = new LinkedHashMap<>();
        for (AiRuntimeConfig c : list) {
            map.put(c.getConfigKey(), c.getValue());
        }
        return map;
    }

    // ==================== AI 中台运行态 / 基线（管理端观测面） ====================

    @Override
    public Map<String, Object> aiRuntimeStatus() {
        Map<String, Object> status = aiPlatformClient.getConfigStatus();
        if (status == null) {
            // AI 中台不可达：返回离线占位，管理端据此引导排查
            Map<String, Object> offline = new HashMap<>();
            offline.put("offline", true);
            return offline;
        }
        return status;
    }

    @Override
    public Map<String, Object> refreshAiRuntime() {
        Map<String, Object> result = aiPlatformClient.refreshConfig();
        if (result == null) {
            throw new BizException(ResultCode.AI_SERVICE_ERROR, "无法连接 AI 中台，配置刷新未执行");
        }
        return result;
    }

    @Override
    public Map<String, Object> promptBaseline() {
        return aiPlatformClient.getPromptBaseline();
    }

    @Override
    public Map<String, Object> agentBaseline() {
        return aiPlatformClient.getAgentBaseline();
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public int promptImportBaseline(Set<String> names) {
        Map<String, Object> baseline = aiPlatformClient.getPromptBaseline();
        if (baseline == null) {
            throw new BizException(ResultCode.AI_SERVICE_ERROR, "无法连接 AI 中台，基线导入失败");
        }
        int imported = 0;
        for (Map.Entry<String, Object> e : baseline.entrySet()) {
            String name = e.getKey();
            if (names != null && !names.isEmpty() && !names.contains(name)) {
                continue;
            }
            @SuppressWarnings("unchecked")
            Map<String, Object> cfg = (Map<String, Object>) e.getValue();
            // 已存在同 name 任意版本 → 跳过，保留管理端已有配置
            Long count = aiPromptMapper.selectCount(
                    new LambdaQueryWrapper<AiPrompt>().eq(AiPrompt::getName, name));
            if (count != null && count > 0) {
                continue;
            }
            AiPrompt p = new AiPrompt();
            p.setName(name);
            p.setVersion("v1");
            p.setTitle(str(cfg.get("title")));
            p.setDescription(str(cfg.get("description")));
            p.setContent(str(cfg.get("content")));
            p.setStatus(1);      // 导入即启用（未激活）；需要热改生效时再「设激活」
            p.setIsActive(false);
            aiPromptMapper.insert(p);
            imported++;
            auditLogService.record("ai_prompt_baseline_import", "ai_prompt", p.getId(), null, name + "/v1");
        }
        log.info("提示词基线导入完成: imported={}", imported);
        return imported;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public int agentImportBaseline(Set<String> codes) {
        Map<String, Object> baseline = aiPlatformClient.getAgentBaseline();
        if (baseline == null) {
            throw new BizException(ResultCode.AI_SERVICE_ERROR, "无法连接 AI 中台，基线导入失败");
        }
        int imported = 0;
        for (Map.Entry<String, Object> e : baseline.entrySet()) {
            String code = e.getKey();
            if (codes != null && !codes.isEmpty() && !codes.contains(code)) {
                continue;
            }
            @SuppressWarnings("unchecked")
            Map<String, Object> cfg = (Map<String, Object>) e.getValue();
            Long count = aiAgentMapper.selectCount(
                    new LambdaQueryWrapper<AiAgent>().eq(AiAgent::getCode, code));
            if (count != null && count > 0) {
                continue;
            }
            AiAgent a = new AiAgent();
            a.setCode(code);
            a.setName(str(cfg.get("name")));
            a.setDescription(str(cfg.get("description")));
            a.setPromptName(code);
            a.setPromptOverride(null);
            Object temp = cfg.get("temperature");
            a.setTemperature(temp != null ? BigDecimal.valueOf(Double.parseDouble(temp.toString())) : null);
            Object tokens = cfg.get("max_tokens");
            a.setMaxTokens(tokens != null ? Integer.valueOf(tokens.toString()) : null);
            a.setToolsConfig(str(cfg.get("tools_config")));
            Object strategy = cfg.get("strategy");
            a.setStrategy(strategy != null ? strategy.toString() : null);
            a.setModel(str(cfg.get("model")));
            Object maxIter = cfg.get("max_iterations");
            a.setMaxIterations(maxIter != null ? Integer.valueOf(maxIter.toString()) : null);
            a.setStatus(1);
            a.setIsActive(false);
            aiAgentMapper.insert(a);
            imported++;
            auditLogService.record("ai_agent_baseline_import", "ai_agent", a.getId(), null, code);
        }
        log.info("Agent 基线导入完成: imported={}", imported);
        return imported;
    }

    private String str(Object v) {
        return v == null ? null : v.toString();
    }

    // ==================== 最近模型事件 ====================

    @Override
    public List<ModelEventLogVO> recentModelEvents(int limit) {
        int capped = Math.min(Math.max(limit, 1), 50);
        List<ModelEventLog> records = modelEventLogMapper.selectList(
                new LambdaQueryWrapper<ModelEventLog>()
                        .orderByDesc(ModelEventLog::getCreatedAt)
                        .orderByDesc(ModelEventLog::getId)
                        .last("LIMIT " + capped));
        if (records == null || records.isEmpty()) {
            return new java.util.ArrayList<>();
        }
        List<ModelEventLogVO> list = new java.util.ArrayList<>(records.size());
        for (ModelEventLog el : records) {
            list.add(ModelEventLogVO.builder()
                    .id(el.getId())
                    .eventType(el.getEventType())
                    .modelName(el.getModelName())
                    .capability(el.getCapability())
                    .errorMessage(el.getErrorMessage())
                    .detailJson(el.getDetailJson())
                    .traceId(el.getTraceId())
                    .recovered(Boolean.TRUE.equals(el.getRecovered()))
                    .createdAt(el.getCreatedAt())
                    .build());
        }
        return list;
    }

    // ==================== 私有工具 ====================

    private AiPrompt requirePrompt(Long id) {
        AiPrompt p = aiPromptMapper.selectById(id);
        if (p == null) {
            throw new BizException(ResultCode.NOT_FOUND, "提示词不存在");
        }
        return p;
    }

    private AiAgent requireAgent(Long id) {
        AiAgent a = aiAgentMapper.selectById(id);
        if (a == null) {
            throw new BizException(ResultCode.NOT_FOUND, "Agent 不存在");
        }
        return a;
    }

    private AiRuntimeConfig requireRuntime(Long id) {
        AiRuntimeConfig c = aiRuntimeConfigMapper.selectById(id);
        if (c == null) {
            throw new BizException(ResultCode.NOT_FOUND, "运行参数不存在");
        }
        return c;
    }

    private void checkDuplicatePrompt(String name, Long excludeId, String version) {
        String ver = StringUtils.hasText(version) ? version : "v1";
        LambdaQueryWrapper<AiPrompt> wrapper = new LambdaQueryWrapper<AiPrompt>()
                .eq(AiPrompt::getName, name)
                .eq(AiPrompt::getVersion, ver);
        if (excludeId != null) {
            wrapper.ne(AiPrompt::getId, excludeId);
        }
        if (aiPromptMapper.selectCount(wrapper) > 0) {
            throw new BizException(ResultCode.BAD_REQUEST, "该逻辑键下已存在同版本提示词：" + name + "/" + ver);
        }
    }

    private void checkDuplicateAgent(String code, Long excludeId, String name) {
        // code 是 Agent 的唯一逻辑键，同 code 只允许一条记录（不同版本用版本字段更合理，此处按 code 唯一）
        LambdaQueryWrapper<AiAgent> wrapper = new LambdaQueryWrapper<AiAgent>()
                .eq(AiAgent::getCode, code);
        if (excludeId != null) {
            wrapper.ne(AiAgent::getId, excludeId);
        }
        if (aiAgentMapper.selectCount(wrapper) > 0) {
            throw new BizException(ResultCode.BAD_REQUEST, code + " 已存在（一个逻辑键仅允许一条 Agent 配置）");
        }
    }

    private void apply(AiPrompt p, AiPromptDTO dto) {
        p.setName(dto.getName().trim());
        p.setVersion(dto.getVersion());
        p.setTitle(dto.getTitle());
        p.setDescription(dto.getDescription());
        p.setContent(dto.getContent());
        p.setStatus(dto.getStatus());
    }

    private void apply(AiAgent a, AiAgentDTO dto) {
        a.setCode(dto.getCode().trim());
        a.setName(dto.getName());
        a.setDescription(dto.getDescription());
        a.setPromptName(dto.getPromptName());
        a.setPromptOverride(dto.getPromptOverride());
        a.setTemperature(dto.getTemperature());
        a.setMaxTokens(dto.getMaxTokens());
        a.setToolsConfig(dto.getToolsConfig());
        a.setStrategy(dto.getStrategy());
        a.setModel(dto.getModel());
        a.setMaxIterations(dto.getMaxIterations());
        a.setStatus(dto.getStatus());
    }

    private void apply(AiRuntimeConfig c, AiRuntimeConfigDTO dto) {
        c.setConfigKey(dto.getConfigKey().trim());
        c.setConfigName(dto.getConfigName());
        c.setDescription(dto.getDescription());
        c.setConfigType(dto.getConfigType());
        c.setValue(dto.getValue());
        c.setDefaultValue(dto.getDefaultValue());
        c.setMin(dto.getMin());
        c.setMax(dto.getMax());
        c.setStep(dto.getStep());
    }

    private AiPromptVO toPromptVO(AiPrompt p) {
        if (p == null) {
            return null;
        }
        return AiPromptVO.builder()
                .id(p.getId()).name(p.getName()).version(p.getVersion()).title(p.getTitle())
                .description(p.getDescription()).content(p.getContent())
                .isActive(Boolean.TRUE.equals(p.getIsActive())).status(p.getStatus())
                .createdAt(p.getCreatedAt()).updatedAt(p.getUpdatedAt()).build();
    }

    private AiAgentVO toAgentVO(AiAgent a) {
        if (a == null) {
            return null;
        }
        return AiAgentVO.builder()
                .id(a.getId()).code(a.getCode()).name(a.getName()).description(a.getDescription())
                .promptName(a.getPromptName()).promptOverride(a.getPromptOverride())
                .temperature(a.getTemperature()).maxTokens(a.getMaxTokens())
                .toolsConfig(a.getToolsConfig())
                .strategy(a.getStrategy()).model(a.getModel()).maxIterations(a.getMaxIterations())
                .isActive(Boolean.TRUE.equals(a.getIsActive())).status(a.getStatus())
                .createdAt(a.getCreatedAt()).updatedAt(a.getUpdatedAt()).build();
    }

    private AiRuntimeConfigVO toRuntimeVO(AiRuntimeConfig c) {
        if (c == null) {
            return null;
        }
        return AiRuntimeConfigVO.builder()
                .id(c.getId()).configKey(c.getConfigKey()).configName(c.getConfigName())
                .description(c.getDescription()).configType(c.getConfigType()).value(c.getValue())
                .defaultValue(c.getDefaultValue()).min(c.getMin()).max(c.getMax()).step(c.getStep())
                .isActive(Boolean.TRUE.equals(c.getIsActive()))
                .createdAt(c.getCreatedAt()).updatedAt(c.getUpdatedAt()).build();
    }

    private boolean isBoolean(String v) {
        return "true".equalsIgnoreCase(v) || "false".equalsIgnoreCase(v);
    }

    private boolean isNumeric(String v) {
        try {
            Double.parseDouble(v.trim());
            return true;
        } catch (NumberFormatException e) {
            return false;
        }
    }
}
