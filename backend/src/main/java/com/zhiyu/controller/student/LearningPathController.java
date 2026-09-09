package com.zhiyu.controller.student;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.client.AiPlatformClient;
import com.zhiyu.common.R;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.service.StudentRecommendService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.Duration;
import java.util.Map;

/**
 * 学生端-学习路径生成接口（PRD 9.3）
 * 由业务中台组装学生事实快照（薄弱点/错题/候选资源），调用 AI 中台学习教练 Agent
 * 生成「知识水平诊断 + 递进学习路径」。
 * studentId 一律取当前登录用户（防越权），请求体不再接收目标学生 ID。
 *
 * 性能说明：AI 全量生成实测 20~90 秒，进页即调会导致移动端长时间白屏转圈。
 * 故生成结果写 Redis（TTL 24h）：进页默认读缓存秒开，
 * 仅移动端显式传 refresh=true（用户点「重新生成路径」）才真正调用 AI 并覆盖缓存。
 */
@Slf4j
@Tag(name = "学生-学习路径")
@RestController
@RequestMapping("/api/v1/student/learning-path")
@RequiredArgsConstructor
public class LearningPathController {

    private static final String CACHE_KEY_PREFIX = "learning:path:";
    private static final Duration CACHE_TTL = Duration.ofHours(24);

    private final AiPlatformClient aiPlatformClient;
    private final StudentRecommendService studentRecommendService;
    private final StringRedisTemplate redisTemplate;
    private final ObjectMapper objectMapper;

    @Operation(summary = "生成学习路径（为当前登录学生；refresh=true 强制重新生成）")
    @PostMapping("/generate")
    public R<Map<String, Object>> generate(
            @RequestParam(value = "refresh", required = false, defaultValue = "false") boolean refresh) {
        // 安全说明：不接收请求体，studentId 一律取当前登录用户，
        // 学生无法传入任意 studentId 获取他人学习路径（防越权）。
        Long studentId = UserContext.requireUserId();
        String cacheKey = CACHE_KEY_PREFIX + studentId;

        // 1. 非强制刷新时优先读缓存（秒开）
        if (!refresh) {
            Map<String, Object> cached = readCache(cacheKey);
            if (cached != null) {
                return R.ok(cached);
            }
        }

        try {
            // 2. 事实快照：真实薄弱点 + 错题 + 候选资源（防幻觉）
            Map<String, Object> facts = studentRecommendService.buildLearningFacts();
            String data = aiPlatformClient.generateLearningPath(studentId, facts);
            if (!StringUtils.hasText(data)) {
                // AI 失败时兜底返回旧缓存，总比报错强
                Map<String, Object> stale = readCache(cacheKey);
                if (stale != null) {
                    return R.ok(stale);
                }
                return R.fail(500, "AI 暂不可用，无法生成学习路径");
            }
            Map<String, Object> result = aiPlatformClient.parseData(data);
            writeCache(cacheKey, result);
            return R.ok(result);
        } catch (Exception e) {
            log.warn("学习路径生成失败 studentId={}: {}", studentId, e.getMessage());
            Map<String, Object> stale = readCache(cacheKey);
            if (stale != null) {
                return R.ok(stale);
            }
            return R.fail(500, "AI 暂不可用，无法生成学习路径");
        }
    }

    private Map<String, Object> readCache(String cacheKey) {
        try {
            String cached = redisTemplate.opsForValue().get(cacheKey);
            if (StringUtils.hasText(cached)) {
                return objectMapper.readValue(cached,
                        new com.fasterxml.jackson.core.type.TypeReference<Map<String, Object>>() {});
            }
        } catch (Exception e) {
            log.warn("读取学习路径缓存失败: {}", e.getMessage());
        }
        return null;
    }

    private void writeCache(String cacheKey, Map<String, Object> result) {
        try {
            redisTemplate.opsForValue().set(cacheKey, objectMapper.writeValueAsString(result), CACHE_TTL);
        } catch (Exception e) {
            log.warn("写入学习路径缓存失败: {}", e.getMessage());
        }
    }
}
