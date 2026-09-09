package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.entity.ClassMaterial;
import com.zhiyu.entity.StudentClassMembership;
import com.zhiyu.entity.TeacherClassAuthorization;
import com.zhiyu.entity.Textbook;
import com.zhiyu.entity.TeachingClass;
import com.zhiyu.mapper.ClassMaterialMapper;
import com.zhiyu.mapper.StudentClassMembershipMapper;
import com.zhiyu.mapper.TeacherClassAuthorizationMapper;
import com.zhiyu.mapper.TeachingClassMapper;
import com.zhiyu.mapper.TextbookMapper;
import com.zhiyu.service.ClassMaterialService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;

/**
 * 班级资料库服务实现
 * 教师端：上传 / 引用教材库 / 移除（创建教师与授权教师均可管理）
 * 学生端：仅班级成员可查看
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ClassMaterialServiceImpl implements ClassMaterialService {

    private final ClassMaterialMapper materialMapper;
    private final TeachingClassMapper classMapper;
    private final TeacherClassAuthorizationMapper authorizationMapper;
    private final StudentClassMembershipMapper membershipMapper;
    private final TextbookMapper textbookMapper;

    @Value("${zhiyu.upload.dir:./uploads}")
    private String uploadDir;

    @Value("${zhiyu.upload.base-url:/uploads}")
    private String uploadBaseUrl;

    /** 支持的资料类型：文档 / 课件 / 音视频 / 图片 / 电子书 */
    private static final Set<String> ALLOWED_EXT = Set.of(
            "pdf", "ppt", "pptx", "doc", "docx", "txt", "epub",
            "mp4", "mov", "mp3", "wav", "m4a",
            "png", "jpg", "jpeg", "gif", "webp");

    private static final long MAX_BYTES = 200 * 1024 * 1024; // 200MB，音视频较常见

    // ---------------- 教师端 ----------------

    @Override
    public List<Map<String, Object>> teacherList(Long classId) {
        requireManageable(classId);
        List<ClassMaterial> mats = materialMapper.selectList(
                new LambdaQueryWrapper<ClassMaterial>()
                        .eq(ClassMaterial::getClassId, classId)
                        .orderByDesc(ClassMaterial::getId));
        // 教材引用批量取教材信息（避免 N+1）
        List<Long> tbIds = mats.stream()
                .filter(m -> "textbook".equals(m.getSourceType()) && m.getTextbookId() != null)
                .map(ClassMaterial::getTextbookId)
                .distinct().toList();
        Map<Long, Textbook> tbById = tbIds.isEmpty() ? Map.of()
                : textbookMapper.selectBatchIds(tbIds).stream()
                        .collect(java.util.stream.Collectors.toMap(Textbook::getId, t -> t));
        List<Map<String, Object>> rows = new ArrayList<>(mats.size());
        for (ClassMaterial m : mats) {
            rows.add(toRow(m, m.getTextbookId() == null ? null : tbById.get(m.getTextbookId()), false));
        }
        return rows;
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Long upload(Long classId, String title, Integer durationSec, MultipartFile file) {
        requireManageable(classId);
        if (file == null || file.isEmpty()) {
            throw new BizException(ResultCode.BAD_REQUEST, "文件不能为空");
        }
        if (file.getSize() > MAX_BYTES) {
            throw new BizException(ResultCode.BAD_REQUEST, "文件大小不能超过 200MB");
        }
        String original = file.getOriginalFilename();
        String ext = extOf(original);
        if (!ALLOWED_EXT.contains(ext)) {
            throw new BizException(ResultCode.BAD_REQUEST,
                    "不支持的文件格式：" + ext + "（支持 pdf/ppt/pptx/doc/docx/txt/epub/mp4/mp3/图片）");
        }
        String stored = storeFile(file, "materials");
        String url = uploadBaseUrl + "/materials/" + stored;

        ClassMaterial m = new ClassMaterial();
        m.setClassId(classId);
        m.setSourceType("upload");
        m.setMaterialType(materialTypeOf(ext));
        m.setTitle(title == null || title.isBlank()
                ? (original == null ? "未命名资料" : original) : title.trim());
        m.setFileUrl(url);
        m.setObjectKey("materials/" + stored);
        m.setDurationSec(durationSec);
        m.setCreatorId(UserContext.requireUserId());
        materialMapper.insert(m);
        log.info("教师{}上传班级资料 classId={} materialId={} type={}",
                m.getCreatorId(), classId, m.getId(), m.getMaterialType());
        return m.getId();
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Long referenceTextbook(Long classId, Long textbookId) {
        requireManageable(classId);
        Textbook tb = textbookMapper.selectById(textbookId);
        if (tb == null) {
            throw new BizException(ResultCode.NOT_FOUND, "教材不存在");
        }
        // 防重复引用
        Long dup = materialMapper.selectCount(new LambdaQueryWrapper<ClassMaterial>()
                .eq(ClassMaterial::getClassId, classId)
                .eq(ClassMaterial::getSourceType, "textbook")
                .eq(ClassMaterial::getTextbookId, textbookId));
        if (dup != null && dup > 0) {
            throw new BizException(ResultCode.BAD_REQUEST, "该教材已在本班资料中，无需重复引用");
        }
        ClassMaterial m = new ClassMaterial();
        m.setClassId(classId);
        m.setSourceType("textbook");
        m.setMaterialType(materialTypeOf(extOf(tb.getFileUrl())));
        m.setTitle(tb.getTitle() == null || tb.getTitle().isBlank() ? "未命名教材" : tb.getTitle());
        m.setTextbookId(textbookId);
        m.setFileUrl(tb.getFileUrl());
        m.setCreatorId(UserContext.requireUserId());
        materialMapper.insert(m);
        return m.getId();
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void remove(Long classId, Long materialId) {
        requireManageable(classId);
        ClassMaterial m = materialMapper.selectById(materialId);
        if (m == null || !classId.equals(m.getClassId())) {
            throw new BizException(ResultCode.NOT_FOUND, "资料不存在");
        }
        materialMapper.deleteById(m.getId());
    }

    // ---------------- 学生端 ----------------

    @Override
    public List<Map<String, Object>> studentList(Long classId) {
        Long uid = UserContext.requireUserId();
        // 仅班级成员可见
        Long inClass = membershipMapper.selectCount(new LambdaQueryWrapper<StudentClassMembership>()
                .eq(StudentClassMembership::getStudentId, uid)
                .eq(StudentClassMembership::getClassId, classId));
        if (inClass == null || inClass == 0) {
            throw new BizException(ResultCode.FORBIDDEN, "仅班级成员可查看班级资料");
        }
        List<ClassMaterial> mats = materialMapper.selectList(
                new LambdaQueryWrapper<ClassMaterial>()
                        .eq(ClassMaterial::getClassId, classId)
                        .orderByDesc(ClassMaterial::getId));
        List<Long> tbIds = mats.stream()
                .filter(m -> "textbook".equals(m.getSourceType()) && m.getTextbookId() != null)
                .map(ClassMaterial::getTextbookId)
                .distinct().toList();
        Map<Long, Textbook> tbById = tbIds.isEmpty() ? Map.of()
                : textbookMapper.selectBatchIds(tbIds).stream()
                        .collect(java.util.stream.Collectors.toMap(Textbook::getId, t -> t));
        List<Map<String, Object>> rows = new ArrayList<>(mats.size());
        for (ClassMaterial m : mats) {
            rows.add(toRow(m, m.getTextbookId() == null ? null : tbById.get(m.getTextbookId()), true));
        }
        return rows;
    }

    // ---------------- helpers ----------------

    private Map<String, Object> toRow(ClassMaterial m, Textbook tb, boolean forStudent) {
        Map<String, Object> row = new LinkedHashMap<>();
        row.put("id", m.getId());
        row.put("sourceType", m.getSourceType());
        row.put("materialType", m.getMaterialType());
        row.put("title", m.getTitle());
        row.put("fileUrl", m.getFileUrl());
        row.put("durationSec", m.getDurationSec());
        row.put("createdAt", m.getCreatedAt());
        if (tb != null) {
            row.put("textbookId", tb.getId());
            row.put("textbookNo", tb.getTextbookNo());
            row.put("coverUrl", tb.getCoverUrl());
            row.put("department", tb.getDepartment());
            row.put("publisher", tb.getPublisher());
            row.put("edition", tb.getEdition());
        }
        if (!forStudent) {
            row.put("creatorId", m.getCreatorId());
        }
        return row;
    }

    /** 教师（创建者或授权教师）可管理班级资料 */
    private void requireManageable(Long classId) {
        Long tid = UserContext.requireUserId();
        TeachingClass tc = classMapper.selectById(classId);
        if (tc == null || (tc.getIsDeleted() != null && tc.getIsDeleted() == 1)) {
            throw new BizException(ResultCode.CLASS_NOT_FOUND);
        }
        if (Objects.equals(tc.getTeacherId(), tid)) {
            return;
        }
        Long authCnt = authorizationMapper.selectCount(
                new LambdaQueryWrapper<TeacherClassAuthorization>()
                        .eq(TeacherClassAuthorization::getTeacherId, tid)
                        .eq(TeacherClassAuthorization::getClassId, classId));
        if (authCnt == null || authCnt == 0) {
            throw new BizException(ResultCode.CLASS_FORBIDDEN);
        }
    }

    private String extOf(String filename) {
        if (filename == null || !filename.contains(".")) {
            return "";
        }
        return filename.substring(filename.lastIndexOf('.') + 1).toLowerCase();
    }

    /** 扩展名 → 资料大类（移动端按大类分流预览） */
    private String materialTypeOf(String ext) {
        return switch (ext) {
            case "pdf" -> "pdf";
            case "ppt", "pptx" -> "ppt";
            case "doc", "docx" -> "doc";
            case "txt" -> "txt";
            case "epub" -> "epub";
            case "mp4", "mov" -> "mp4";
            case "mp3", "wav", "m4a" -> "mp3";
            case "png", "jpg", "jpeg", "gif", "webp" -> "image";
            default -> "link";
        };
    }

    /** 存储文件到 uploadDir 子目录，返回文件名 */
    private String storeFile(MultipartFile file, String subDir) {
        try {
            Path dir = Paths.get(uploadDir, subDir);
            Files.createDirectories(dir);
            String ext = extOf(file.getOriginalFilename());
            String filename = UUID.randomUUID().toString().replace("-", "") + "." + ext;
            Path target = dir.resolve(filename);
            file.transferTo(target.toFile());
            return filename;
        } catch (IOException e) {
            throw new BizException(ResultCode.BAD_REQUEST, "文件存储失败: " + e.getMessage());
        }
    }
}
