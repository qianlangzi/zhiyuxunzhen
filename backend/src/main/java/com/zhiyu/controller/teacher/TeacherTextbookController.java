package com.zhiyu.controller.teacher;

import com.zhiyu.common.R;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.TextbookService;
import com.zhiyu.service.dto.TextbookCreateDTO;
import com.zhiyu.vo.TextbookVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.Map;
import java.util.UUID;

/**
 * 教师端-教材（电子书）管理接口
 * 上传电子书文件 + 创建/查看/下架自己的教材，供学生端教材中心查阅
 */
@Tag(name = "教师-教材管理")
@RestController
@RequestMapping("/api/v1/teacher/textbooks")
@RequiredArgsConstructor
public class TeacherTextbookController {

    private final TextbookService textbookService;

    @Value("${zhiyu.upload.dir:./uploads}")
    private String uploadDir;

    @Value("${zhiyu.upload.base-url:/uploads}")
    private String uploadBaseUrl;

    @Operation(summary = "上传电子书文件（pdf/epub），返回文件访问 URL")
    @PostMapping("/upload")
    public R<Map<String, String>> upload(@RequestParam("file") MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new BizException(ResultCode.VALIDATION_FAILED, "文件不能为空");
        }
        long maxBytes = 50 * 1024 * 1024; // 50MB
        if (file.getSize() > maxBytes) {
            throw new BizException(ResultCode.VALIDATION_FAILED, "电子书文件大小不能超过 50MB");
        }
        String origName = file.getOriginalFilename();
        String ext = "";
        if (origName != null && origName.contains(".")) {
            ext = origName.substring(origName.lastIndexOf('.')).toLowerCase();
        }
        if (!ext.matches("\\.(pdf|epub|txt|doc|docx)")) {
            throw new BizException(ResultCode.VALIDATION_FAILED,
                    "仅支持 pdf/epub/txt/doc/docx 格式");
        }
        try {
            Path dir = Paths.get(uploadDir, "ebooks");
            Files.createDirectories(dir);
            String filename = "ebook_" + UUID.randomUUID() + ext;
            Path target = dir.resolve(filename);
            file.transferTo(target.toFile());
            String url = uploadBaseUrl + "/ebooks/" + filename;
            return R.ok(Map.of("url", url, "filename", origName));
        } catch (IOException e) {
            throw new BizException(ResultCode.FILE_UPLOAD_ERROR, "文件上传失败：" + e.getMessage());
        }
    }

    @Operation(summary = "创建/上传教材（含电子书元数据）")
    @PostMapping
    public R<Long> create(@Valid @RequestBody TextbookCreateDTO dto) {
        return R.ok(textbookService.create(dto));
    }

    @Operation(summary = "我的教材列表（分页）")
    @GetMapping
    public R<PageResult<TextbookVO>> myList(
            @RequestParam(defaultValue = "1") Integer pageNum,
            @RequestParam(defaultValue = "10") Integer pageSize) {
        return R.ok(textbookService.myList(pageNum, pageSize));
    }

    @Operation(summary = "下架教材")
    @DeleteMapping("/{id}")
    public R<Void> delete(@PathVariable Long id) {
        textbookService.delete(id);
        return R.ok();
    }
}