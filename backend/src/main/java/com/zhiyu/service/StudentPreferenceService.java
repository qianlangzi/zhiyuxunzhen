package com.zhiyu.service;

import java.util.Map;
import java.util.Set;

/**
 * AI 学伴用户偏好服务（语气档位 + 记忆开关）
 * 偏好服务端持久化（user_preference 表），换设备一致；后端组装学情上下文时读取并注入 AI。
 */
public interface StudentPreferenceService {

    /** 偏好键：语气档位 */
    String KEY_TONE = "ai_tone";

    /** 偏好键：记忆开关 */
    String KEY_MEMORY_ENABLED = "ai_memory_enabled";

    /** 默认语气：温暖鼓励 */
    String DEFAULT_TONE = "warm";

    /** 支持的语气档位：warm 温暖鼓励 / strict 严谨专业 / lively 活泼轻松 / concise 简洁高效 */
    Set<String> SUPPORTED_TONES = Set.of("warm", "strict", "lively", "concise");

    /**
     * 当前学生偏好（无记录时给默认值）
     *
     * @return {aiTone: String, aiMemoryEnabled: Boolean}
     */
    Map<String, Object> current();

    /**
     * 更新偏好（字段为空则跳过）
     *
     * @param tone          语气档位，非法值抛 BAD_REQUEST
     * @param memoryEnabled 记忆开关
     */
    void update(String tone, Boolean memoryEnabled);
}
