package com.zhiyu.service;

import com.zhiyu.service.dto.LessonPlanCreateDTO;
import com.zhiyu.service.dto.LessonPublishDTO;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.Map;

/**
 * 智能备课服务（助教核心：教学设计 + 病例 + 课件资料 + 发布闭环）
 */
public interface TeacherLessonService {

    /** 创建备课包 */
    Long createLesson(LessonPlanCreateDTO req);

    /** 更新备课包 */
    void updateLesson(Long lessonId, LessonPlanCreateDTO req);

    /** 备课包列表（含资料数与发布状态） */
    List<Map<String, Object>> listLessons();

    /** 备课包详情（含资料列表、病例摘要、教学设计） */
    Map<String, Object> lessonDetail(Long lessonId);

    /** 删除备课包 */
    void deleteLesson(Long lessonId);

    /** 批量删除备课包（多选删除，含废案清理） */
    void batchDeleteLessons(List<Long> lessonIds);

    /** 拖动排序：按传入顺序保存教案展示序号（仅本人教案，未包含的教案保持原序号） */
    void sortLessons(List<Long> lessonIds);

    /**
     * 智能合并多个备课包为一个
     *
     * @param lessonIds 参与合并的备课包 ID（按列表顺序，首个为基础载体）
     * @param title     合并后的教案标题（为空则沿用首个标题）
     * @return 合并后新备课包 ID
     */
    Long mergeLessons(List<Long> lessonIds, String title);

    /** AI 生成教学设计（调 AI 中台 /lesson/design），返回并缓存 */
    Map<String, Object> generateDesign(Long lessonId);

    /**
     * AI 生成课件素材/PPT 提纲（调 AI 中台 /lesson/ppt）
     * 基于教案 ai_design_json 生成分页 PPT 提纲并缓存到 ppt_outline_json；AI 降级时返回 null。
     */
    Map<String, Object> generatePpt(Long lessonId);

    /** 保存人工确认/编辑后的 PPT 课件提纲到 ppt_outline_json */
    void savePpt(Long lessonId, Map<String, Object> ppt);

    /**
     * 向导式备课对话（调 AI 中台 /lesson/guide）
     *
     * @param lessonId  备课包 ID
     * @param userReply 用户对本轮问题的回答
     * @return {question, field, options, optionsHint, complete, summary, missing}
     */
    Map<String, Object> guide(Long lessonId, String userReply);

    /** 导出教案 Word 文档（含关联病例内容与附件清单），返回 {url, filename} */
    Map<String, Object> exportDoc(Long lessonId);

    /** 上传课件资料（PDF/PPT/MP4/MP3/图片） */
    Long addMaterial(Long lessonId, String materialType, String title,
                     String knowledgeTags, Integer durationSec, MultipartFile file);

    /** 删除课件资料 */
    void removeMaterial(Long lessonId, Long materialId);

    /** 我的全部备课资料（跨教案平铺，供作业创建时选择「资料附件」任务项） */
    List<Map<String, Object>> listMyMaterials();

    /** 发布备课（materialOnly=1 仅发资料；否则创建作业一并下发） */
    void publish(Long lessonId, LessonPublishDTO req);

    /** 学生端：学习任务聚合列表（资料任务 + 作业任务） */
    List<Map<String, Object>> studentTasks();

    /** 学生端：单个学习任务详情 */
    Map<String, Object> studentTaskDetail(Long publishId);

    /** 学生端：标记资料任务完成（幂等，仅班级成员可操作；完成后从待办/课程角标清除） */
    void completeLessonTask(Long publishId);
}
