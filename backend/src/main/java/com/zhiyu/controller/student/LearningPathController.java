package com.zhiyu.controller.student;

import com.zhiyu.client.AiPlatformClient;
import com.zhiyu.common.R;
import com.zhiyu.common.context.UserContext;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 学生端-学习路径生成接口（PRD 9.3）
 * 调用 AI 中台为当前学生生成个性化补救学习路径。
 * studentId 一律取当前登录用户（防越权），请求体不再接收目标学生 ID。
 */
@Tag(name = "学生-学习路径")
@RestController
@RequestMapping("/api/v1/student/learning-path")
@RequiredArgsConstructor
public class LearningPathController {

    private final AiPlatformClient aiPlatformClient;

    @Operation(summary = "生成学习路径（为当前登录学生）")
    @PostMapping("/generate")
    public R<String> generate() {
        Long studentId = UserContext.requireUserId();
        try {
            String data = aiPlatformClient.generateLearningPath(studentId);
            if (!StringUtils.hasText(data)) {
                return R.fail(500, "AI 暂不可用，无法生成学习路径");
            }
            return R.ok(data);
        } catch (Exception e) {
            return R.fail(500, "AI 暂不可用，无法生成学习路径");
        }
    }
}
