package com.zhiyu.controller.teacher;

import com.zhiyu.common.R;
import com.zhiyu.service.TeacherLessonService;
import com.zhiyu.service.dto.LessonBatchDTO;
import com.zhiyu.service.dto.LessonGuideDTO;
import com.zhiyu.service.dto.LessonPlanCreateDTO;
import com.zhiyu.service.dto.LessonPublishDTO;
import com.zhiyu.service.dto.LessonSortDTO;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.Map;

/**
 * 教师端智能备课（助教核心）
 * 备课包 = 教学设计 + 病例 + 课件资料 + 发布闭环（资料可独立发放）
 */
@RestController
@RequestMapping("/api/v1/teacher/lessons")
@RequiredArgsConstructor
public class TeacherLessonController {

    private final TeacherLessonService lessonService;

    @PostMapping
    public R<Long> create(@Valid @RequestBody LessonPlanCreateDTO req) {
        return R.ok(lessonService.createLesson(req));
    }

    @PutMapping("/{id}")
    public R<Void> update(@PathVariable Long id, @Valid @RequestBody LessonPlanCreateDTO req) {
        lessonService.updateLesson(id, req);
        return R.ok();
    }

    @GetMapping
    public R<List<Map<String, Object>>> list() {
        return R.ok(lessonService.listLessons());
    }

    @GetMapping("/{id}")
    public R<Map<String, Object>> detail(@PathVariable Long id) {
        return R.ok(lessonService.lessonDetail(id));
    }

    @DeleteMapping("/{id}")
    public R<Void> delete(@PathVariable Long id) {
        lessonService.deleteLesson(id);
        return R.ok();
    }

    /** 批量删除教案（多选删除，含废案清理） */
    @PostMapping("/batch-delete")
    public R<Void> batchDelete(@RequestBody(required = false) LessonBatchDTO req) {
        lessonService.batchDeleteLessons(req == null ? null : req.getIds());
        return R.ok();
    }

    /** 智能合并多个教案为一个（归并目标/重难点/教学设计与病例） */
    @PostMapping("/merge")
    public R<Long> merge(@RequestBody LessonBatchDTO req) {
        return R.ok(lessonService.mergeLessons(req.getIds(), req.getTitle()));
    }

    /** 拖动排序：按传入顺序保存教案展示序号 */
    @PostMapping("/sort")
    public R<Void> sort(@RequestBody LessonSortDTO req) {
        lessonService.sortLessons(req == null ? null : req.getLessonIds());
        return R.ok();
    }

    /** AI 生成教学设计（教案大纲/课堂活动/讨论题） */
    @PostMapping("/{id}/design")
    public R<Map<String, Object>> generateDesign(@PathVariable Long id) {
        return R.ok(lessonService.generateDesign(id));
    }

    /** AI 生成课件素材/PPT 提纲（基于已生成的教案设计，教师确认编辑后发布） */
    @PostMapping("/{id}/ppt")
    public R<Map<String, Object>> generatePpt(@PathVariable Long id) {
        return R.ok(lessonService.generatePpt(id));
    }

    /** 保存人工确认/编辑后的 PPT 课件提纲 */
    @PutMapping("/{id}/ppt")
    public R<Void> savePpt(@PathVariable Long id,
                           @RequestBody(required = false) Map<String, Object> ppt) {
        lessonService.savePpt(id, ppt);
        return R.ok();
    }

    /** 向导式备课对话：教师回答本轮问题，AI 返回下一个问题或需求单 */
    @PostMapping("/{id}/guide")
    public R<Map<String, Object>> guide(
            @PathVariable Long id,
            @RequestBody(required = false) LessonGuideDTO req) {
        String reply = (req == null || req.getUserReply() == null) ? "" : req.getUserReply();
        return R.ok(lessonService.guide(id, reply));
    }

    /** 导出教案 Word 文档（含关联病例内容与附件清单） */
    @PostMapping("/{id}/export")
    public R<Map<String, Object>> export(@PathVariable Long id) {
        return R.ok(lessonService.exportDoc(id));
    }

    /** 上传课件资料（PDF/PPT/MP4/MP3/图片） */
    @PostMapping("/{id}/materials")
    public R<Long> addMaterial(
            @PathVariable Long id,
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "materialType", required = false) String materialType,
            @RequestParam(value = "title", required = false) String title,
            @RequestParam(value = "knowledgeTags", required = false) String knowledgeTags,
            @RequestParam(value = "durationSec", required = false) Integer durationSec) {
        return R.ok(lessonService.addMaterial(id, materialType, title, knowledgeTags, durationSec, file));
    }

    @DeleteMapping("/{id}/materials/{materialId}")
    public R<Void> removeMaterial(@PathVariable Long id, @PathVariable Long materialId) {
        lessonService.removeMaterial(id, materialId);
        return R.ok();
    }

    /** 发布备课：materialOnly=true 仅发资料；否则资料+病例+作业一并下发 */
    @PostMapping("/{id}/publish")
    public R<Void> publish(@PathVariable Long id, @Valid @RequestBody LessonPublishDTO req) {
        lessonService.publish(id, req);
        return R.ok();
    }
}
