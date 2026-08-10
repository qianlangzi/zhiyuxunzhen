package com.zhiyu.controller.student;

import com.zhiyu.common.R;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.exception.BizException;
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
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

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

    @Operation(summary = "上传问诊影像（本地目录存储，返回 URL）")
    @PostMapping("/{sessionId}/image")
    public R<Map<String, String>> uploadImage(@PathVariable Long sessionId,
                                              @RequestParam("file") MultipartFile file) {
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