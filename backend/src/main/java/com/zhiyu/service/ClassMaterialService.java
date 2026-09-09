package com.zhiyu.service;

import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.Map;

/**
 * 班级资料库服务（班级详情「资料」板块）
 */
public interface ClassMaterialService {

    /** 教师端：班级资料列表（上传 + 教材引用混合，按时间倒序） */
    List<Map<String, Object>> teacherList(Long classId);

    /** 教师端：上传资料文件（pdf/ppt/doc/docx/txt/epub/mp4/mp3/图片） */
    Long upload(Long classId, String title, Integer durationSec, MultipartFile file);

    /** 教师端：引用教材库教材 */
    Long referenceTextbook(Long classId, Long textbookId);

    /** 教师端：移除资料（逻辑删除，引用与上传同处理） */
    void remove(Long classId, Long materialId);

    /** 学生端：班级资料列表（仅班级成员可见） */
    List<Map<String, Object>> studentList(Long classId);
}
