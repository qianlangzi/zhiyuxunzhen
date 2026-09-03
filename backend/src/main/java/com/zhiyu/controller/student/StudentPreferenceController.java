package com.zhiyu.controller.student;

import com.zhiyu.common.R;
import com.zhiyu.service.StudentPreferenceService;
import com.zhiyu.service.dto.PreferenceUpdateRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * 学生-AI 学伴偏好（语气档位 + 记忆开关）
 * 服务端持久化，多端一致；仅学伴链路生效，不含标准 SP。
 */
@Tag(name = "学生-AI学伴偏好")
@RestController
@RequestMapping("/api/v1/student/preferences")
@RequiredArgsConstructor
public class StudentPreferenceController {

    private final StudentPreferenceService preferenceService;

    @Operation(summary = "获取当前学生 AI 学伴偏好（语气档位 + 记忆开关）")
    @GetMapping
    public R<Map<String, Object>> get() {
        return R.ok(preferenceService.current());
    }

    @Operation(summary = "更新 AI 学伴偏好（按需传 aiTone / aiMemoryEnabled）")
    @PutMapping
    public R<Void> update(@RequestBody PreferenceUpdateRequest req) {
        preferenceService.update(req.getAiTone(), req.getAiMemoryEnabled());
        return R.ok();
    }
}
