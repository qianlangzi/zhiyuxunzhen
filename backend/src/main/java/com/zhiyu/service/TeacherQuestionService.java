package com.zhiyu.service;

import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.dto.TeacherQuestionCreateDTO;
import com.zhiyu.vo.TeacherQuestionVO;

/**
 * 教师端-基础题库录入与服务（进入管理端审核闭环）
 *
 * <p>审核状态流转：0未提交(草稿/驳回后) → 1待审核 → 2通过(学生可见) / 3驳回(教师可改后重新提交)。
 */
public interface TeacherQuestionService {

    /**
     * 创建基础题（草稿，adminAuditStatus=0，submitterId=当前教师）
     */
    Long create(TeacherQuestionCreateDTO dto);

    /**
     * 更新题目（仅草稿态或驳回态可改；改后回到草稿态需重新提交）
     */
    void update(Long id, TeacherQuestionCreateDTO dto);

    /**
     * 提交审核（草稿 0 → 待审核 1；已提交/已通过不可重复提交）
     */
    void submit(Long id);

    /**
     * 删除题目（仅草稿态或驳回态）
     */
    void delete(Long id);

    /**
     * 我的题目列表（含审核状态；可按状态筛选，默认只看自己创建的）
     */
    PageResult<TeacherQuestionVO> myQuestions(Integer pageNum, Integer pageSize, Integer adminAuditStatus);

    /**
     * 全部题库列表（含所有人已录入题目；支持审核状态 / 科室 / 知识点 / 难度 / 题型筛选 + 关键字搜索）
     *
     * @param order 发布时间排序方向：asc=最早优先，desc（默认）=最新优先
     */
    PageResult<TeacherQuestionVO> allQuestions(Integer pageNum, Integer pageSize, Integer adminAuditStatus,
                                               String department, String knowledgeTag, Integer difficulty,
                                               String questionType, String keyword, String order);

    /**
     * 我的题目详情
     */
    TeacherQuestionVO detail(Long id);

    /**
     * 题库公开详情（供「全部题库」查看他人题目，不做归属校验）
     */
    TeacherQuestionVO detailPublic(Long id);
}