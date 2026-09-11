package com.zhiyu.controller.student;

import com.zhiyu.common.R;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.client.AiPlatformClient;
import com.zhiyu.entity.ChatSession;
import com.zhiyu.service.StudentSessionService;
import com.zhiyu.service.dto.ChatMessageDTO;
import com.zhiyu.service.dto.SessionStartDTO;
import com.zhiyu.vo.SessionStartVO;
import com.zhiyu.vo.StudentSessionDetailVO;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.Executor;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

/**
 * 学生端-问诊会话接口（PRD 5.2 第 1 步）
 * 学生选择病例进入问诊室，创建 ChatSession 后由前端携带 sessionId 调 FastAPI SSE 接口
 */
@Tag(name = "学生-问诊会话")
@Slf4j
@RestController
@RequestMapping("/api/v1/student/sessions")
@RequiredArgsConstructor
public class StudentSessionController {

    private final StudentSessionService studentSessionService;
    private final AiPlatformClient aiPlatformClient;

    /**
     * SSE 流式转发专用异步执行器：与 StudentCompanionController 复用同一线程池，
     * 避免 Spring 默认 Executor 被长连接占满导致其它控制器阻塞。
     * 注：lombok @RequiredArgsConstructor 不识别 @Qualifier，因此走 setter 注入。
     */
    @jakarta.annotation.Resource(name = "aiTaskExecutor")
    public void setAiTaskExecutor(Executor executor) {
        this.aiTaskExecutor = executor;
    }
    private Executor aiTaskExecutor;

    @Value("${zhiyu.upload.dir:./uploads}")
    private String uploadDir;

    @Value("${zhiyu.upload.base-url:/uploads}")
    private String uploadBaseUrl;

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

    /**
     * 导师按需小结（2026-09-03）：训练态不在对话流实时推送思维树/提示（防剧透），
     * 学生通过左滑手势主动唤出时按需生成：思维树 + 苏格拉底提示一次返回。
     */
    @Operation(summary = "按需获取当前会话的思维树与苏格拉底提示")
    @GetMapping("/{sessionId}/mentor")
    public R<Map<String, Object>> mentor(@PathVariable Long sessionId) {
        return R.ok(studentSessionService.mentor(sessionId));
    }

    @Operation(summary = "结束本人问诊会话")
    @PostMapping("/{sessionId}/finish")
    public R<Void> finish(@PathVariable Long sessionId) {
        studentSessionService.finish(sessionId);
        return R.ok();
    }

    @Operation(summary = "重试异常问诊会话的 AI 评估归档")
    @PostMapping("/{sessionId}/archive/retry")
    public R<Void> retryArchive(@PathVariable Long sessionId) {
        studentSessionService.retryArchive(sessionId);
        return R.ok();
    }

    @Operation(summary = "发送问诊消息（转发 AI 中台同步接口，返回 SP 回复）")
    @PostMapping("/{sessionId}/chat")
    public R<Map<String, Object>> chat(@PathVariable Long sessionId,
                                       @Valid @RequestBody ChatMessageDTO req) {
        return R.ok(studentSessionService.chat(sessionId, req.getMessage()));
    }

    /**
     * 流式问诊（SSE）· 转发 AI 中台 /internal/chat/stream，事件契约与同步接口一致：
     * message / tree / stage / socrates / safety / citation / status / error / done。
     * 前端可用此接口实现 ChatGPT 式打字机效果；前端发起流式请求前若需 server-side
     * 校验失败，统一以 error/done 事件约定收尾，不直接 5xx，便于前端做加载失败重试。
     */
    @Operation(summary = "发送问诊消息（流式 SSE，AI 中台 /internal/chat/stream 透传）")
    @PostMapping(value = "/{sessionId}/chat/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter chatStream(@PathVariable Long sessionId,
                                 @Valid @RequestBody ChatMessageDTO req) {
        // 关键：UserContext 是 ThreadLocal，仅在请求主线程有效；必须在这里同步取出登录态，
        // 再传入 aiTaskExecutor 的异步线程，否则异步线程里 ThreadLocal 为空会报“未登录或token无效”。
        final Long studentId;
        try {
            studentId = UserContext.requireUserId();
        } catch (BizException e) {
            SseEmitter emitter = new SseEmitter(0L);
            safeSendError(emitter, e.getMessage());
            return emitter;
        }
        final String message = req.getMessage();
        final SseEmitter emitter = new SseEmitter(0L); // 0 = 不超时；前端关闭 / done 自然收尾
        aiTaskExecutor.execute(() -> {
            ChatSession session;
            try {
                session = studentSessionService.requireSessionForStudent(sessionId, studentId);
            } catch (BizException e) {
                log.warn("问诊流式校验失败: sessionId={} err={}", sessionId, e.getMessage());
                safeSendError(emitter, e.getMessage());
                return;
            } catch (Exception e) {
                log.warn("问诊流式鉴权异常: sessionId={} err={}", sessionId, e.getMessage());
                safeSendError(emitter, "会话校验失败");
                return;
            }
            if (session.getStatus() != null && session.getStatus() != 0) {
                safeSendError(emitter, "问诊会话已结束");
                return;
            }
            try {
                // 在异步线程内直接读取并转发 AI 中台 SSE 流（流读取发生在 AiPlatformClient 的
                // RestTemplate ResponseExtractor 回调内，避免 RestTemplate 关闭底层流）。
                aiPlatformClient.streamChat(
                        session.getId(),
                        studentId,
                        session.getCaseId(),
                        message,
                        emitter);
            } catch (BizException e) {
                log.warn("AI 问诊流式调用失败: sessionId={} err={}", sessionId, e.getMessage());
                safeSendError(emitter, e.getMessage());
            } catch (Exception e) {
                log.warn("AI 问诊流式转发异常: sessionId={} err={}", sessionId, e.getMessage());
                safeSendError(emitter, "AI 问诊流式服务异常");
            }
        });
        return emitter;
    }

    private static void safeSendError(SseEmitter emitter, String message) {
        try {
            emitter.send(SseEmitter.event()
                    .name("error")
                    .data("{\"message\":\"" + message.replace("\"", "\\\"") + "\"}"));
            emitter.send(SseEmitter.event()
                    .name("done")
                    .data("{}"));
            emitter.complete();
        } catch (Exception ex) {
            emitter.completeWithError(ex);
        }
    }

    @Operation(summary = "上传问诊影像（本地目录存储，返回 URL）")
    @PostMapping("/{sessionId}/image")
    public R<Map<String, String>> uploadImage(@PathVariable Long sessionId,
                                              @RequestParam("file") MultipartFile file) {
        // 会话归属校验：此前只校验文件本身，sessionId 完全不过问 —— 任意登录学生
        // 都能拿别人的 sessionId 上传文件（污染存储、绕过问诊边界）。与
        // analyzeImage 保持同一道门（2026-09-11 修复）。
        studentSessionService.requireSessionForStudent(sessionId, UserContext.requireUserId());
        if (file == null || file.isEmpty()) {
            throw new BizException(ResultCode.VALIDATION_FAILED, "文件不能为空");
        }
        long maxBytes = 10 * 1024 * 1024; // 10MB
        if (file.getSize() > maxBytes) {
            throw new BizException(ResultCode.VALIDATION_FAILED, "文件大小不能超过 10MB");
        }
        String origName = file.getOriginalFilename();
        String ext = "";
        if (origName != null && origName.contains(".")) {
            ext = origName.substring(origName.lastIndexOf('.')).toLowerCase();
        }
        if (!ext.matches("\\.(jpg|jpeg|png|gif|bmp|webp)")) {
            throw new BizException(ResultCode.VALIDATION_FAILED, "仅支持常见图片格式");
        }
        try {
            Path dir = Paths.get(uploadDir, "multimodal");
            Files.createDirectories(dir);
            String filename = "img_" + UUID.randomUUID() + ext;
            Path target = dir.resolve(filename);
            file.transferTo(target.toFile());
            String url = uploadBaseUrl + "/multimodal/" + filename;
            return R.ok(Map.of("url", url, "filename", filename));
        } catch (IOException e) {
            throw new BizException(ResultCode.FILE_UPLOAD_ERROR, "文件上传失败：" + e.getMessage());
        }
    }

    @Operation(summary = "影像 AI 读图分析（多模态；未配置模型时返回降级提示）")
    @PostMapping("/{sessionId}/image/analyze")
    public R<Map<String, Object>> analyzeImage(@PathVariable Long sessionId,
                                               @RequestBody Map<String, Object> req,
                                               HttpServletRequest request) {
        String imageUrl = req.get("imageUrl") == null ? null : String.valueOf(req.get("imageUrl"));
        if (imageUrl == null || imageUrl.isBlank()) {
            throw new BizException(ResultCode.VALIDATION_FAILED, "imageUrl 不能为空");
        }
        List<Double> imageBbox = new ArrayList<>();
        Object bboxRaw = req.get("imageBbox");
        if (bboxRaw instanceof List<?> list) {
            for (Object o : list) {
                if (o instanceof Number n) imageBbox.add(n.doubleValue());
            }
        }
        String studentNote = req.get("studentNote") == null ? null : String.valueOf(req.get("studentNote"));
        String auth = request.getHeader(HttpHeaders.AUTHORIZATION);
        return R.ok(studentSessionService.analyzeImage(sessionId, imageUrl, imageBbox, studentNote, auth));
    }
}
