package com.zhiyu.controller.student;

import com.zhiyu.client.AiPlatformClient;
import com.zhiyu.common.R;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.entity.CompanionMemory;
import com.zhiyu.service.CompanionConversationService;
import com.zhiyu.service.CompanionMemoryService;
import com.zhiyu.service.StudentPreferenceService;
import com.zhiyu.service.StudentRecommendService;
import com.zhiyu.service.dto.CompanionRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Executor;

/**
 * 学生 AI 学伴（P1-2，学习陪伴）
 * 平辈陪伴式对话，角色区别于 SP（标准病人）；Spring Boot 组装学生学情上下文
 * （薄弱点/近期错题/进度/偏好/长期记忆）后转发 AI 中台，学伴据此给个性化策略建议。
 * 提供同步（/companion）与流式（/companion/stream, SSE）两种接口。
 */
@Slf4j
@Tag(name = "学生-AI学伴")
@RestController
@RequestMapping("/api/v1/student/companion")
@RequiredArgsConstructor
public class StudentCompanionController {

    private final AiPlatformClient aiPlatformClient;
    private final StudentRecommendService studentRecommendService;
    private final StudentPreferenceService preferenceService;
    private final CompanionConversationService companionConversationService;
    private final CompanionMemoryService memoryService;
    private final Executor aiTaskExecutor;

    /** 组装学生学情上下文（薄弱点/近期错题/进度 + 偏好 + 长期记忆），供学伴个性化建议 */
    private Map<String, Object> buildContext() {
        try {
            Map<String, Object> context = new HashMap<>(studentRecommendService.buildLearningFacts());
            // AI 学伴偏好：语气档位 + 记忆开关（user_preference，服务端持久化）
            Map<String, Object> preferences = preferenceService.current();
            context.put("preferences", preferences);
            // 记忆开关开启时召回该生最近记忆注入，实现跨会话个性化（companion_memory）
            if (Boolean.TRUE.equals(preferences.get("aiMemoryEnabled"))) {
                List<CompanionMemory> memories = memoryService.recent(CompanionMemoryService.RECALL_LIMIT);
                if (!memories.isEmpty()) {
                    context.put("memory", memories.stream()
                            .map(m -> Map.of("factType", m.getFactType(), "content", m.getContent()))
                            .toList());
                }
            }
            return context;
        } catch (Exception e) {
            log.warn("学伴学情上下文组装失败，降级为空上下文: {}", e.getMessage());
            return Map.of();
        }
    }

    @Operation(summary = "AI 学伴对话（同步）")
    @PostMapping
    public R<Map<String, Object>> chat(@Valid @RequestBody CompanionRequest req) {
        try {
            Long studentId = UserContext.requireUserId();
            Map<String, Object> data = aiPlatformClient.companionSync(
                            req.getMessage(),
                            req.getHistory(),
                            buildContext(),
                            req.getImageUrl(),
                            studentId,
                            ownedConversationId(req.getConversationId())
                    );
            return R.ok(data);
        } catch (BizException e) {
            return R.fail(e.getCode(), e.getMessage());
        } catch (Exception e) {
            log.warn("AI学伴同步调用失败: {}", e.getMessage());
            return R.fail(ResultCode.AI_SERVICE_ERROR.getCode(), "AI学伴服务异常");
        }
    }

    /**
     * 流式 AI 学伴对话（SSE）。移动端以 text/event-stream 消费，
     * 事件契约：message / status / safety / error / done，收到 done 后前端自行收尾。
     */
    @Operation(summary = "AI 学伴对话（流式 SSE）")
    @PostMapping(value = "/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter chatStream(@Valid @RequestBody CompanionRequest req) {
        SseEmitter emitter = new SseEmitter(0L); // 0 = 不超时，由前端关闭或 done 收尾
        // 学情上下文与学生 ID 在主线程组装/取出（依赖请求线程资源），
        // 流读取与转发发生在 AiPlatformClient 的 RestTemplate ResponseExtractor 回调内
        // （避免流被提前关闭；异步线程拿不到 UserContext，故在此处取出）。
        Long studentId = UserContext.requireUserId();
        Map<String, Object> context = buildContext();
        Long conversationId = ownedConversationId(req.getConversationId());
        aiTaskExecutor.execute(() -> {
            try {
                aiPlatformClient.companionStream(
                        req.getMessage(), req.getHistory(), context, req.getImageUrl(),
                        studentId, conversationId, emitter);
            } catch (BizException e) {
                log.warn("AI学伴流式转发失败: {}", e.getMessage());
                emitter.completeWithError(e);
            } catch (Exception e) {
                log.warn("AI学伴流式读取异常: {}", e.getMessage());
                emitter.completeWithError(new BizException(ResultCode.AI_SERVICE_ERROR, "AI学伴流式服务异常"));
            }
        });
        return emitter;
    }

    /** 会话 id 归属校验：属于当前学生则透传（供记忆来源标注），否则返回 null（不传给 AI） */
    private Long ownedConversationId(Long conversationId) {
        if (conversationId == null) {
            return null;
        }
        return companionConversationService.isOwned(conversationId) ? conversationId : null;
    }
}
