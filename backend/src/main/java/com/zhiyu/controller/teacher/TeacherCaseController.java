package com.zhiyu.controller.teacher;

import com.zhiyu.common.R;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.TeacherCaseService;
import com.zhiyu.service.dto.CaseCreateDTO;
import com.zhiyu.service.dto.CaseUpdateDTO;
import com.zhiyu.vo.CasePreviewVO;
import com.zhiyu.vo.TeacherCaseListVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 教师端-病例管理接口（PRD 4.1 / 9.1）
 */
@Tag(name = "教师-病例管理")
@RestController
@RequestMapping("/api/v1/teacher/cases")
@RequiredArgsConstructor
public class TeacherCaseController {

    private final TeacherCaseService teacherCaseService;

    /** 病例多模态素材上传目录（与问诊影像同源，静态映射 /uploads/**） */
    @org.springframework.beans.factory.annotation.Value("${zhiyu.upload.dir:./uploads}")
    private String uploadDir;

    @org.springframework.beans.factory.annotation.Value("${zhiyu.upload.base-url:/uploads}")
    private String uploadBaseUrl;

    @Operation(summary = "上传病例多模态素材（图片/PDF/音频/视频，≤20MB，返回可访问 URL）")
    @PostMapping("/media")
    public R<java.util.Map<String, String>> uploadMedia(
            @RequestParam("file") org.springframework.web.multipart.MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new com.zhiyu.common.exception.BizException(
                    com.zhiyu.common.constant.ResultCode.VALIDATION_FAILED, "文件不能为空");
        }
        long maxBytes = 20 * 1024 * 1024; // 20MB
        if (file.getSize() > maxBytes) {
            throw new com.zhiyu.common.exception.BizException(
                    com.zhiyu.common.constant.ResultCode.VALIDATION_FAILED, "文件不能超过 20MB");
        }
        String origName = file.getOriginalFilename();
        String ext = "";
        if (origName != null && origName.contains(".")) {
            ext = origName.substring(origName.lastIndexOf('.')).toLowerCase();
        }
        boolean isImage = ext.matches("\\.(jpg|jpeg|png|gif|bmp|webp)");
        boolean isDoc = ext.matches("\\.(pdf)");
        boolean isAudio = ext.matches("\\.(mp3|wav|m4a|aac)");
        boolean isVideo = ext.matches("\\.(mp4|mov|m4v)");
        if (!isImage && !isDoc && !isAudio && !isVideo) {
            throw new com.zhiyu.common.exception.BizException(
                    com.zhiyu.common.constant.ResultCode.VALIDATION_FAILED,
                    "仅支持图片/PDF/音频/视频素材");
        }
        try {
            java.nio.file.Path dir = java.nio.file.Paths.get(uploadDir, "multimodal");
            java.nio.file.Files.createDirectories(dir);
            String filename = "case_" + java.util.UUID.randomUUID() + ext;
            java.nio.file.Path target = dir.resolve(filename);
            file.transferTo(target.toFile());
            String url = uploadBaseUrl + "/multimodal/" + filename;
            String mediaType = isImage ? "image" : isDoc ? "pdf" : isAudio ? "audio" : "video";
            return R.ok(java.util.Map.of("url", url, "mediaType", mediaType, "filename", filename));
        } catch (java.io.IOException e) {
            throw new com.zhiyu.common.exception.BizException(
                    com.zhiyu.common.constant.ResultCode.FILE_UPLOAD_ERROR,
                    "素材上传失败：" + e.getMessage());
        }
    }

    @Operation(summary = "创建病例")
    @PostMapping
    public R<Long> create(@Valid @RequestBody CaseCreateDTO req) {
        return R.ok(teacherCaseService.create(req));
    }

    @Operation(summary = "更新病例")
    @PutMapping("/{id}")
    public R<Void> update(@PathVariable Long id, @Valid @RequestBody CaseUpdateDTO req) {
        teacherCaseService.update(id, req);
        return R.ok();
    }

    @Operation(summary = "我的病例列表（分页，status: 0草稿 1已发布，为空不过滤）")
    @GetMapping
    public R<PageResult<TeacherCaseListVO>> list(
            @RequestParam(defaultValue = "1") Integer pageNum,
            @RequestParam(defaultValue = "10") Integer pageSize,
            @RequestParam(required = false) String title,
            @RequestParam(required = false) String department,
            @RequestParam(required = false) Integer status) {
        return R.ok(teacherCaseService.myCases(pageNum, pageSize, title, department, status));
    }

    @Operation(summary = "全部病例列表（含所有教师的病例，分页+筛选）")
    @GetMapping("/all")
    public R<PageResult<TeacherCaseListVO>> allList(
            @RequestParam(defaultValue = "1") Integer pageNum,
            @RequestParam(defaultValue = "10") Integer pageSize,
            @RequestParam(required = false) String title,
            @RequestParam(required = false) String department,
            @RequestParam(required = false) Integer status) {
        return R.ok(teacherCaseService.allCases(pageNum, pageSize, title, department, status));
    }

    @Operation(summary = "预览病例配置（含隐藏疾病、标准路径）")
    @GetMapping("/{id}/preview")
    public R<CasePreviewVO> preview(@PathVariable Long id) {
        return R.ok(teacherCaseService.preview(id));
    }

    @Operation(summary = "病例公开预览（全部病例中查看他人病例）")
    @GetMapping("/public/{id}/preview")
    public R<CasePreviewVO> previewPublic(@PathVariable Long id) {
        return R.ok(teacherCaseService.previewPublic(id));
    }

    @Operation(summary = "发布病例到病例广场（提交管理员审核）")
    @PostMapping("/{id}/publish-to-market")
    public R<Void> publishToMarket(@PathVariable Long id) {
        teacherCaseService.publishToMarket(id);
        return R.ok();
    }

    @Operation(summary = "删除草稿病例（仅本人、仅草稿可删）")
    @DeleteMapping("/{id}")
    public R<Void> delete(@PathVariable Long id) {
        teacherCaseService.delete(id);
        return R.ok();
    }
}
