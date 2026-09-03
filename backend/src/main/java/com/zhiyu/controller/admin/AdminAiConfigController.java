package com.zhiyu.controller.admin;

import com.zhiyu.common.R;
import com.zhiyu.common.param.PageParam;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.AiConfigService;
import com.zhiyu.service.dto.AiAgentDTO;
import com.zhiyu.service.dto.AiPromptDTO;
import com.zhiyu.service.dto.AiRuntimeConfigDTO;
import com.zhiyu.vo.AiAgentVO;
import com.zhiyu.vo.AiPromptVO;
import com.zhiyu.vo.AiRuntimeConfigVO;
import com.zhiyu.vo.ModelEventLogVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * AI 配置中心（提示词 · Agent 元参数 · RAG 运行参数 热更新）
 *
 * 仅管理员(role=4)可访问（PermissionInterceptor 默认 /api/v1/admin/** → 4）。
 * 与 /models（模型连接参数）共同构成完整的「AI 配置中心」。
 */
@Tag(name = "管理端-AI配置中心")
@RestController
@RequestMapping("/api/v1/admin/ai-config")
@RequiredArgsConstructor
public class AdminAiConfigController {

    private final AiConfigService aiConfigService;

    // ==================== 提示词 ====================

    @Operation(summary = "提示词分页列表（可按逻辑键过滤）")
    @GetMapping("/prompts")
    public R<PageResult<AiPromptVO>> promptPage(PageParam param,
                                                @RequestParam(required = false) String name) {
        return R.ok(aiConfigService.promptPage(param, name));
    }

    @Operation(summary = "新增提示词")
    @PostMapping("/prompts")
    public R<AiPromptVO> promptCreate(@Valid @RequestBody AiPromptDTO dto) {
        return R.ok(aiConfigService.promptCreate(dto));
    }

    @Operation(summary = "更新提示词")
    @PutMapping("/prompts/{id}")
    public R<AiPromptVO> promptUpdate(@PathVariable Long id, @Valid @RequestBody AiPromptDTO dto) {
        return R.ok(aiConfigService.promptUpdate(id, dto));
    }

    @Operation(summary = "删除提示词")
    @DeleteMapping("/prompts/{id}")
    public R<Void> promptDelete(@PathVariable Long id) {
        aiConfigService.promptDelete(id);
        return R.ok();
    }

    @Operation(summary = "切换提示词激活（可在运行态立即应用并核验）")
    @PostMapping("/prompts/{id}/active")
    public R<Void> promptSetActive(@PathVariable Long id) {
        aiConfigService.promptSetActive(id);
        return R.ok();
    }

    @Operation(summary = "提示词停用/启用")
    @PostMapping("/prompts/{id}/toggle")
    public R<Void> promptToggle(@PathVariable Long id) {
        aiConfigService.promptToggle(id);
        return R.ok();
    }

    // ==================== Agent ====================

    @Operation(summary = "Agent 分页列表（可按逻辑键过滤）")
    @GetMapping("/agents")
    public R<PageResult<AiAgentVO>> agentPage(PageParam param,
                                              @RequestParam(required = false) String code) {
        return R.ok(aiConfigService.agentPage(param, code));
    }

    @Operation(summary = "新增 Agent")
    @PostMapping("/agents")
    public R<AiAgentVO> agentCreate(@Valid @RequestBody AiAgentDTO dto) {
        return R.ok(aiConfigService.agentCreate(dto));
    }

    @Operation(summary = "更新 Agent")
    @PutMapping("/agents/{id}")
    public R<AiAgentVO> agentUpdate(@PathVariable Long id, @Valid @RequestBody AiAgentDTO dto) {
        return R.ok(aiConfigService.agentUpdate(id, dto));
    }

    @Operation(summary = "删除 Agent")
    @DeleteMapping("/agents/{id}")
    public R<Void> agentDelete(@PathVariable Long id) {
        aiConfigService.agentDelete(id);
        return R.ok();
    }

    @Operation(summary = "切换 Agent 激活（可在运行态立即应用并核验）")
    @PostMapping("/agents/{id}/active")
    public R<Void> agentSetActive(@PathVariable Long id) {
        aiConfigService.agentSetActive(id);
        return R.ok();
    }

    @Operation(summary = "Agent 停用/启用")
    @PostMapping("/agents/{id}/toggle")
    public R<Void> agentToggle(@PathVariable Long id) {
        aiConfigService.agentToggle(id);
        return R.ok();
    }

    // ==================== RAG 运行参数 ====================

    @Operation(summary = "RAG 运行参数列表（可按键模糊过滤）")
    @GetMapping("/runtime")
    public R<PageResult<AiRuntimeConfigVO>> runtimePage(PageParam param,
                                                        @RequestParam(required = false) String configKey) {
        return R.ok(aiConfigService.runtimePage(param, configKey));
    }

    @Operation(summary = "保存 RAG 运行参数（按 config_key upsert）")
    @PostMapping("/runtime")
    public R<AiRuntimeConfigVO> runtimeSave(@Valid @RequestBody AiRuntimeConfigDTO dto) {
        return R.ok(aiConfigService.runtimeSave(dto));
    }

    @Operation(summary = "删除 RAG 运行参数")
    @DeleteMapping("/runtime/{id}")
    public R<Void> runtimeDelete(@PathVariable Long id) {
        aiConfigService.runtimeDelete(id);
        return R.ok();
    }

    // ==================== AI 中台运行态 / 基线（观测面） ====================

    @Operation(summary = "AI 中台运行态快照（各配置生效来源/同步状态/模型脱敏视图）")
    @GetMapping("/status")
    public R<Map<String, Object>> runtimeStatus() {
        return R.ok(aiConfigService.aiRuntimeStatus());
    }

    @Operation(summary = "立即刷新 AI 中台配置并返回生效版本")
    @PostMapping("/refresh")
    public R<Map<String, Object>> refreshRuntime() {
        return R.ok(aiConfigService.refreshAiRuntime());
    }

    @Operation(summary = "AI 中台内置提示词基线（供一键导入）")
    @GetMapping("/baseline/prompts")
    public R<Map<String, Object>> promptBaseline() {
        return R.ok(aiConfigService.promptBaseline());
    }

    @Operation(summary = "AI 中台内置 Agent 元参数基线（供一键导入）")
    @GetMapping("/baseline/agents")
    public R<Map<String, Object>> agentBaseline() {
        return R.ok(aiConfigService.agentBaseline());
    }

    @Operation(summary = "一键导入提示词基线（缺失才导入；names 为空导入全部）")
    @PostMapping("/baseline/prompts/import")
    public R<Integer> promptBaselineImport(@RequestBody(required = false) Set<String> names) {
        return R.ok(aiConfigService.promptImportBaseline(names));
    }

    @Operation(summary = "一键导入 Agent 基线（缺失才导入；codes 为空导入全部）")
    @PostMapping("/baseline/agents/import")
    public R<Integer> agentBaselineImport(@RequestBody(required = false) Set<String> codes) {
        return R.ok(aiConfigService.agentImportBaseline(codes));
    }

    @Operation(summary = "最近模型事件（AI 中台运行事件视图，最多 20 条；不含任何密钥）")
    @GetMapping("/model-events")
    public R<List<ModelEventLogVO>> recentModelEvents(
            @RequestParam(defaultValue = "20") int limit) {
        return R.ok(aiConfigService.recentModelEvents(limit));
    }
}
