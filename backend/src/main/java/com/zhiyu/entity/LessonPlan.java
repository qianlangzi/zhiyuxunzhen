package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableLogic;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

/**
 * 智能备课包（助教核心）
 * 教师教案创作台：对话式需求确认 → AI 生成教案 → 编辑 → 关联病例/课件 → 导出分享
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("lesson_plan")
public class LessonPlan extends BaseEntity {

    private Long teacherId;

    private String title;

    private String department;

    private String targetGrade;

    /** 教学目标 JSON */
    private String objectivesJson;

    /** 教学重难点 JSON */
    private String keyPointsJson;

    /** AI 教学设计 JSON（教案大纲/课堂活动/讨论题） */
    private String aiDesignJson;

    /** AI 生成课件素材/PPT 提纲 JSON（教师确认编辑后使用） */
    private String pptOutlineJson;

    /** 关联 SP 病例 ID */
    private Long caseId;

    /** 病例来源：0无 1自建 2引用病例广场 */
    private Integer caseSource;

    /** 对话确认的备课要素 JSON（主题/教材/学情/课时/重难点/风格） */
    private String teachingElementsJson;

    /** 学情目标班级 ID（备课针对的班级，用于拉取真实学情） */
    private Long targetClassId;

    /** 选用教材 ID */
    private Long textbookId;

    /** 0草稿 1已生成教案 */
    private Integer status;

    /** 是否置顶（1=置顶 0=否），置顶项排在列表最前 */
    private Integer isTop;

    /** 自定义优先级（0 默认，数值越大越靠前），用于手动排布常用教案 */
    private Integer priority;

    /** 手动排序序号（0=未排序，越小越靠前），用于拖动排序持久化 */
    private Integer sortOrder;

    @TableLogic
    private Integer isDeleted;
}
