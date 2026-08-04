package com.zhiyu.controller.student;

import com.zhiyu.common.R;
import com.zhiyu.service.StudentSessionService;
import com.zhiyu.service.dto.ChatMessageDTO;
import com.zhiyu.service.dto.SessionStartDTO;
import com.zhiyu.vo.SessionStartVO;
import com.zhiyu.vo.StudentSessionDetailVO;

import java.util.Map;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 学生端-问诊会话接口（PRD 5.2 第 1 步）
 * 学生选择病例进入问诊室，创建 ChatSession 后由前端携带 sessionId 调 FastAPI SSE 接口
 */
@Tag(name = "学生-问诊会话")
@RestController
@RequestMapping("/api/v1/student/sessions")
@RequiredArgsConstructor
public class StudentSessionController {

    private final StudentSessionService studentSessionService;

    @Operation(summary = "启动问诊会话（创建 ChatSession，返回 sessionId）")
    @PostMapping
    public R<SessionStartVO> start(@Valid @RequestBody SessionStartDTO req) {
        return R.ok(studentSessionService.start(req));
    }

    @Operation(summary = "查询本人问诊会话和历史消息")
    @GetMapping("/{sessionId}")
    public R<StudentSessionDetailVO> detail(@PathVariable Long sessionId) {
        return R.ok(studentSessionService.detail(sessionId));
    }

    @Operation(summary = "结束本人问诊会话")
    @PostMapping("/{sessionId}/finish")
    public R<Void> finish(@PathVariable Long sessionId) {
        studentSessionService.finish(sessionId);
        return R.ok();
    }

    @Operation(summary = "发送问诊消息（转发 AI 中台同步接口，返回 SP 回复）")
    @PostMapping("/{sessionId}/chat")
    public R<Map<String, Object>> chat(@PathVariable Long sessionId,
                                       @Valid @RequestBody ChatMessageDTO req) {
        return R.ok(studentSessionService.chat(sessionId, req.getMessage()));
    }
}
