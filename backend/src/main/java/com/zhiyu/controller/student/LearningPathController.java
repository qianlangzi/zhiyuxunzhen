package com.zhiyu.controller.student;

import com.zhiyu.client.AiPlatformClient;
import com.zhiyu.common.R;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.service.StudentRecommendService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * 学生端-学习路径生成接口（PRD 9.3）
 * 由业务中台组装学生事实快照（薄弱点/错题/候选资源），调用 AI 中台学习教练 Agent
 * 生成「知识水平诊断 + 递进学习路径」。
 * studentId 一律取当前登录用户（防越权），请求体不再接收目标学生 ID。
 */
@Tag(name = "学生-学习路径")
@RestController
@RequestMapping("/api/v1/student/learning-path")
@RequiredArgsConstructor
public class LearningPathController {

    private final AiPlatformClient aiPlatformClient;
    private final StudentRecommendService studentRecommendService;

    @Operation(summary = "生成学习路径（为当前登录学生）")
    @PostMapping("/generate")
    public R<Map<String, Object>> generate() {
        // 安全说明：不接收请求体，studentId 一律取当前登录用户，
        // 学生无法传入任意 studentId 获取他人学习路径（防越权）。
        Long studentId = UserContext.requireUserId();
        try {
            // 事实快照：真实薄弱点 + 错题 + 候选资源（防幻觉）
            Map<String, Object> facts = studentRecommendService.buildLearningFacts();
            String data = aiPlatformClient.generateLearningPath(studentId, facts);
            if (!StringUtils.hasText(data)) {
                return R.fail(500, "AI 暂不可用，无法生成学习路径");
            }
            return R.ok(aiPlatformClient.parseData(data));
        } catch (Exception e) {
            return R.fail(500, "AI 暂不可用，无法生成学习路径");
        }
    }
}
