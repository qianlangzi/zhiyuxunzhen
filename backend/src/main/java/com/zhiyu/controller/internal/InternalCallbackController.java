package com.zhiyu.controller.internal;

import com.zhiyu.common.R;
import com.zhiyu.service.CompanionMemoryService;
import com.zhiyu.service.InternalCallbackService;
import com.zhiyu.service.AiSessionContextService;
import com.zhiyu.service.ModelManageService;
import com.zhiyu.service.AiConfigService;
import com.zhiyu.service.TokenUsageService;
import com.zhiyu.vo.ActiveModelVO;
import com.zhiyu.vo.ActiveAgentVO;
import com.zhiyu.vo.ActivePromptVO;
import com.zhiyu.service.dto.internal.SessionMessageAppendDTO;
import com.zhiyu.service.dto.internal.TokenUsageReportDTO;
import com.zhiyu.service.dto.internal.KnowledgeCallbackDTO;
import com.zhiyu.service.dto.internal.MistakesSyncDTO;
import com.zhiyu.service.dto.internal.ModelEventLogDTO;
import com.zhiyu.service.dto.internal.ReviewCallbackDTO;
import com.zhiyu.service.dto.internal.SessionArchiveDTO;
import com.zhiyu.service.dto.internal.WeaknessSyncDTO;
import com.zhiyu.service.dto.internal.CompanionMemoriesSyncDTO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import com.zhiyu.vo.AiSessionContextVO;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * 内部回调接口（PRD 9.4）
 * 路径前缀 /api/internal，由 InternalApiInterceptor 用 X-Internal-Token 头鉴权，不走 JWT
 */
@Tag(name = "内部回调-AI中台")
@RestController
@RequestMapping("/api/internal")
@RequiredArgsConstructor
public class InternalCallbackController {

    private final InternalCallbackService internalCallbackService;
    private final AiSessionContextService aiSessionContextService;
    private final ModelManageService modelManageService;
    private final AiConfigService aiConfigService;
    private final CompanionMemoryService companionMemoryService;
    private final TokenUsageService tokenUsageService;

    @Operation(summary = "获取经过归属校验的问诊病例上下文")
    @GetMapping("/session/{sessionId}/context")
    public R<AiSessionContextVO> sessionContext(
            @PathVariable Long sessionId,
            @RequestParam Long studentId) {
        return R.ok(aiSessionContextService.getContext(sessionId, studentId));
    }

    @Operation(summary = "获取病例上下文（SP 开场白专用，不依赖会话是否存在）")
    @GetMapping("/case/{caseId}/context")
    public R<AiSessionContextVO> caseContext(@PathVariable Long caseId) {
        return R.ok(aiSessionContextService.getCaseContext(caseId));
    }

    @Operation(summary = "保存问诊消息")
    @PostMapping("/session/{sessionId}/messages")
    public R<Void> appendMessages(
            @PathVariable Long sessionId,
            @Valid @RequestBody SessionMessageAppendDTO dto) {
        aiSessionContextService.appendMessages(sessionId, dto);
        return R.ok();
    }

    @Operation(summary = "归档问诊会话（更新状态、评分、报告、思维树）")
    @PostMapping("/session/archive")
    public R<Void> archiveSession(@Valid @RequestBody SessionArchiveDTO dto) {
        internalCallbackService.archiveSession(dto);
        return R.ok();
    }

    @Operation(summary = "AI批阅结果回调（写入批阅记录，更新作业实例状态为待复核）")
    @PostMapping("/review/callback")
    public R<Void> reviewCallback(@Valid @RequestBody ReviewCallbackDTO dto) {
        internalCallbackService.reviewCallback(dto);
        return R.ok();
    }

    @Operation(summary = "同步错题本（批量插入）")
    @PostMapping("/mistakes/sync")
    public R<Void> syncMistakes(@RequestBody MistakesSyncDTO dto) {
        internalCallbackService.syncMistakes(dto);
        return R.ok();
    }

    @Operation(summary = "同步薄弱知识点（upsert）")
    @PostMapping("/weakness/sync")
    public R<Void> syncWeakness(@RequestBody WeaknessSyncDTO dto) {
        internalCallbackService.syncWeakness(dto);
        return R.ok();
    }

    @Operation(summary = "AI学伴记忆抽取回调（批量写入长期记忆 companion_memory）")
    @PostMapping("/companion/memories")
    public R<Void> syncCompanionMemories(@Valid @RequestBody CompanionMemoriesSyncDTO dto) {
        companionMemoryService.saveFromAi(dto.getStudentId(), dto.getFacts());
        return R.ok();
    }

    @Operation(summary = "获取各能力当前「启用且激活」的模型真实配置（供 AI 中台热读取）")
    @GetMapping("/model/active")
    public R<Map<String, ActiveModelVO>> activeModelConfigs() {
        return R.ok(modelManageService.activeConfigs());
    }

    @Operation(summary = "获取各 name「启用且激活」的提示词（供 AI 中台热读取）")
    @GetMapping("/prompt/active")
    public R<Map<String, ActivePromptVO>> activePrompts() {
        return R.ok(aiConfigService.activePrompts());
    }

    @Operation(summary = "获取各 code「启用且激活」的 Agent 元参数（供 AI 中台热读取）")
    @GetMapping("/agent/active")
    public R<Map<String, ActiveAgentVO>> activeAgents() {
        return R.ok(aiConfigService.activeAgents());
    }

    @Operation(summary = "获取「参与下发」的 RAG 运行参数键值（供 AI 中台热覆盖）")
    @GetMapping("/runtime/active")
    public R<Map<String, String>> activeRuntimeConfigs() {
        return R.ok(aiConfigService.activeRuntimeConfigs());
    }

    @Operation(summary = "记录模型异常和降级事件")
    @PostMapping("/model-event/log")
    public R<Void> logModelEvent(@RequestBody @Valid ModelEventLogDTO dto) {
        internalCallbackService.logModelEvent(dto);
        return R.ok();
    }

    @Operation(summary = "教材向量化入库完成回调（AI 中台异步告知成功/失败）")
    @PostMapping("/knowledge/callback")
    public R<Void> knowledgeCallback(@RequestBody @Valid KnowledgeCallbackDTO dto) {
        internalCallbackService.knowledgeCallback(dto);
        return R.ok();
    }

    @Operation(summary = "Token 用量上报（AI 中台 llm_client 出口统计后异步上报）")
    @PostMapping("/token-usage/report")
    public R<Void> reportTokenUsage(@RequestBody @Valid TokenUsageReportDTO dto) {
        tokenUsageService.report(dto);
        return R.ok();
    }
}
