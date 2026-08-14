package com.zhiyu.controller.student;

import com.zhiyu.client.AiPlatformClient;
import com.zhiyu.common.R;
import com.zhiyu.common.context.UserContext;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 学生端-学习路径生成接口（PRD 9.3）
 * 调用 AI 中台为当前学生生成个性化补救学习路径
 */
@Tag(name = "学生-学习路径")
@RestController
@RequestMapping("/api/v1/student/learning-path")
@RequiredArgsConstructor
public class LearningPathController {

    private final AiPlatformClient aiPlatformClient;

    @Operation(summary = "生成学习路径")
    @PostMapping("/generate")
    public R<String> generate(@RequestBody LearningPathRequest req) {
        // B-P0-3 修复：忽略客户端传入的 studentId，强制使用当前登录用户 ID。
        // 旧实现把 req.getStudentId() 直接发给 AI，学生可传入任意 studentId 获取他人学习路径。
        Long userId = UserContext.requireUserId();
        return R.ok(aiPlatformClient.generateLearningPath(userId));
    }

    @Data
    public static class LearningPathRequest {
        private Long studentId;
    }
}