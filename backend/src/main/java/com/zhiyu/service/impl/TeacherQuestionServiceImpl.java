package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.entity.PracticeQuestion;
import com.zhiyu.entity.Textbook;
import com.zhiyu.mapper.PracticeQuestionMapper;
import com.zhiyu.mapper.TextbookMapper;
import com.zhiyu.service.TeacherQuestionService;
import com.zhiyu.service.dto.TeacherQuestionCreateDTO;
import com.zhiyu.vo.TeacherQuestionVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.util.Collections;
import java.util.List;
import java.util.Objects;
import java.util.stream.Collectors;

/**
 * 教师端-基础题库录入与服务实现
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TeacherQuestionServiceImpl implements TeacherQuestionService {

    private final PracticeQuestionMapper questionMapper;
    private final TextbookMapper textbookMapper;
    private final com.zhiyu.mapper.SysUserMapper sysUserMapper;
    private final ObjectMapper objectMapper;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Long create(TeacherQuestionCreateDTO dto) {
        Long teacherId = UserContext.requireUserId();
        PracticeQuestion q = new PracticeQuestion();
        fillEntity(q, dto);
        q.setStatus(1);
        q.setAdminAuditStatus(0);   // 草稿
        q.setSubmitterId(teacherId);
        q.setRejectReason(null);
        questionMapper.insert(q);
        // 生成统一题号（保留未执行迁移/旧数据的兼容：按 id 回填）
        applyQuestionNo(q);
        questionMapper.updateById(q);
        return q.getId();
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void update(Long id, TeacherQuestionCreateDTO dto) {
        Long teacherId = UserContext.requireUserId();
        PracticeQuestion q = requireOwned(id, teacherId);
        if (q.getAdminAuditStatus() != null && q.getAdminAuditStatus() == 1) {
            // 审核中不可改
            throw new BizException(ResultCode.BAD_REQUEST, "题目审核中，不可编辑");
        }
        if (q.getAdminAuditStatus() != null && q.getAdminAuditStatus() == 2) {
            // 已通过不可改，需走新增
            throw new BizException(ResultCode.QUESTION_SUBMITTED);
        }
        fillEntity(q, dto);
        // 驳回(3)后修改需重新提交，重置为草稿并清空驳回意见
        if (q.getAdminAuditStatus() != null && q.getAdminAuditStatus() == 3) {
            q.setAdminAuditStatus(0);
            q.setRejectReason(null);
        }
        questionMapper.updateById(q);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void submit(Long id) {
        Long teacherId = UserContext.requireUserId();
        PracticeQuestion q = requireOwned(id, teacherId);
        if (q.getAdminAuditStatus() != null && q.getAdminAuditStatus() == 1) {
            throw new BizException(ResultCode.QUESTION_SUBMITTED, "题目已在审核中，请勿重复提交");
        }
        if (q.getAdminAuditStatus() != null && q.getAdminAuditStatus() == 2) {
            throw new BizException(ResultCode.QUESTION_SUBMITTED, "题目已通过审核，不可重复提交");
        }
        q.setAdminAuditStatus(1);   // 草稿(0)/驳回(3) → 待审核(1)
        questionMapper.updateById(q);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void delete(Long id) {
        Long teacherId = UserContext.requireUserId();
        PracticeQuestion q = requireOwned(id, teacherId);
        if (q.getAdminAuditStatus() != null && q.getAdminAuditStatus() == 1) {
            throw new BizException(ResultCode.BAD_REQUEST, "题目审核中，不可删除");
        }
        if (q.getAdminAuditStatus() != null && q.getAdminAuditStatus() == 2) {
            throw new BizException(ResultCode.QUESTION_SUBMITTED, "题目已通过审核，不可删除");
        }
        questionMapper.deleteById(id);
    }

    @Override
    public PageResult<TeacherQuestionVO> myQuestions(Integer pageNum, Integer pageSize, Integer adminAuditStatus) {
        Long teacherId = UserContext.requireUserId();
        return query(pageNum, pageSize, adminAuditStatus, true, teacherId,
                null, null, null, null, null, false);
    }

    @Override
    public PageResult<TeacherQuestionVO> allQuestions(Integer pageNum, Integer pageSize, Integer adminAuditStatus,
                                                      String department, String knowledgeTag, Integer difficulty,
                                                      String questionType, String keyword, String order) {
        return query(pageNum, pageSize, adminAuditStatus, false, null,
                department, knowledgeTag, difficulty, questionType, keyword,
                "asc".equalsIgnoreCase(order));
    }

    /**
     * 题库分页通用查询。
     *
     * @param onlyMine  是否仅查本人创建的题目
     * @param teacherId 仅本人时当前教师 id
     * @param ascending 发布时间是否升序（false = 最新优先）
     */
    private PageResult<TeacherQuestionVO> query(Integer pageNum, Integer pageSize,
                                                Integer adminAuditStatus, boolean onlyMine, Long teacherId,
                                                String department, String knowledgeTag, Integer difficulty,
                                                String questionType, String keyword, boolean ascending) {
        Page<PracticeQuestion> page = new Page<>(pageNum, pageSize);
        LambdaQueryWrapper<PracticeQuestion> wrapper = new LambdaQueryWrapper<PracticeQuestion>()
                .eq(onlyMine, PracticeQuestion::getSubmitterId, onlyMine ? teacherId : null)
                .eq(adminAuditStatus != null, PracticeQuestion::getAdminAuditStatus, adminAuditStatus)
                .eq(StringUtils.hasText(department), PracticeQuestion::getDepartment, department)
                .eq(StringUtils.hasText(knowledgeTag), PracticeQuestion::getKnowledgeTag, knowledgeTag)
                .eq(difficulty != null, PracticeQuestion::getDifficulty, difficulty)
                .eq(StringUtils.hasText(questionType), PracticeQuestion::getQuestionType, questionType)
                .like(StringUtils.hasText(keyword), PracticeQuestion::getTitle, keyword);
        if (ascending) {
            wrapper.orderByAsc(PracticeQuestion::getCreatedAt);
        } else {
            wrapper.orderByDesc(PracticeQuestion::getCreatedAt);
        }
        questionMapper.selectPage(page, wrapper);

        List<Long> tbIds = page.getRecords().stream()
                .map(PracticeQuestion::getSourceTextbookId)
                .filter(Objects::nonNull).distinct().collect(Collectors.toList());
        java.util.Map<Long, String> tbMap = tbIds.isEmpty() ? Collections.emptyMap() : textbookMapper.selectList(
                        new LambdaQueryWrapper<Textbook>().in(Textbook::getId, tbIds))
                .stream().collect(Collectors.toMap(Textbook::getId, Textbook::getTitle, (a, b) -> a));

        // 批量取提交人姓名，避免 N+1（全部题库展示作者）
        List<Long> submitterIds = page.getRecords().stream()
                .map(PracticeQuestion::getSubmitterId)
                .filter(Objects::nonNull).distinct().collect(Collectors.toList());
        java.util.Map<Long, String> creatorMap = submitterIds.isEmpty() ? Collections.emptyMap()
                : sysUserMapper.selectList(
                        new LambdaQueryWrapper<com.zhiyu.entity.SysUser>()
                                .in(com.zhiyu.entity.SysUser::getId, submitterIds)
                                .select(com.zhiyu.entity.SysUser::getId, com.zhiyu.entity.SysUser::getRealName))
                .stream()
                .filter(u -> u.getRealName() != null && !u.getRealName().isBlank())
                .collect(Collectors.toMap(com.zhiyu.entity.SysUser::getId,
                        com.zhiyu.entity.SysUser::getRealName, (a, b) -> a));

        List<TeacherQuestionVO> list = page.getRecords().stream()
                .map(q -> toVO(q,
                        q.getSourceTextbookId() == null ? null : tbMap.get(q.getSourceTextbookId()),
                        q.getSubmitterId() == null ? null : creatorMap.get(q.getSubmitterId())))
                .collect(Collectors.toList());
        return PageResult.of(page, list);
    }

    @Override
    public TeacherQuestionVO detail(Long id) {
        Long teacherId = UserContext.requireUserId();
        PracticeQuestion q = requireOwned(id, teacherId);
        return toDetailVO(q);
    }

    @Override
    public TeacherQuestionVO detailPublic(Long id) {
        PracticeQuestion q = questionMapper.selectById(id);
        if (q == null) {
            throw new BizException(ResultCode.QUESTION_NOT_FOUND);
        }
        return toDetailVO(q);
    }

    private TeacherQuestionVO toDetailVO(PracticeQuestion q) {
        String tbTitle = null;
        if (q.getSourceTextbookId() != null) {
            Textbook tb = textbookMapper.selectById(q.getSourceTextbookId());
            tbTitle = tb == null ? null : tb.getTitle();
        }
        String creatorName = null;
        if (q.getSubmitterId() != null) {
            com.zhiyu.entity.SysUser u = sysUserMapper.selectById(q.getSubmitterId());
            creatorName = u == null ? null : u.getRealName();
        }
        return toVO(q, tbTitle, creatorName);
    }

    // ==================== 私有工具 ====================

    private PracticeQuestion requireOwned(Long id, Long teacherId) {
        PracticeQuestion q = questionMapper.selectById(id);
        if (q == null) {
            throw new BizException(ResultCode.QUESTION_NOT_FOUND);
        }
        if (!Objects.equals(q.getSubmitterId(), teacherId)) {
            throw new BizException(ResultCode.FORBIDDEN, "无权操作他人的题目");
        }
        return q;
    }

    private void fillEntity(PracticeQuestion q, TeacherQuestionCreateDTO dto) {
        q.setQuestionType(dto.getQuestionType());
        q.setDepartment(dto.getDepartment());
        q.setKnowledgeTag(dto.getKnowledgeTag());
        q.setTitle(dto.getTitle());
        q.setOptionsJson(serializeOptions(dto.getOptions()));
        q.setAnswer(dto.getAnswer());
        q.setExplanation(dto.getExplanation());
        q.setDifficulty(dto.getDifficulty());
        q.setSourceTextbookId(dto.getSourceTextbookId());
    }

    private String serializeOptions(List<String> options) {
        if (options == null || options.isEmpty()) {
            return null;
        }
        try {
            return objectMapper.writeValueAsString(options);
        } catch (JsonProcessingException e) {
            throw new BizException(ResultCode.BAD_REQUEST, "选项格式错误");
        }
    }

    /**
     * 为新创建题目生成统一题号，格式 ST + 6 位零填充 id。
     * 若数据库迁移已回填过则保留已有值。
     */
    private void applyQuestionNo(PracticeQuestion q) {
        if (q.getQuestionNo() == null || q.getQuestionNo().isBlank()) {
            q.setQuestionNo(String.format("ST%06d", q.getId()));
        }
    }

    private TeacherQuestionVO toVO(PracticeQuestion q, String tbTitle, String creatorName) {
        List<String> options = Collections.emptyList();
        if (StringUtils.hasText(q.getOptionsJson())) {
            try {
                options = objectMapper.readValue(q.getOptionsJson(),
                        new com.fasterxml.jackson.core.type.TypeReference<List<String>>() {
                        });
            } catch (Exception e) {
                log.warn("解析选项失败: id={}", q.getId());
            }
        }
        return TeacherQuestionVO.builder()
                .id(q.getId())
                .questionNo(q.getQuestionNo())
                .questionType(q.getQuestionType())
                .department(q.getDepartment())
                .knowledgeTag(q.getKnowledgeTag())
                .title(q.getTitle())
                .options(options)
                .answer(q.getAnswer())
                .explanation(q.getExplanation())
                .difficulty(q.getDifficulty())
                .sourceTextbookId(q.getSourceTextbookId())
                .sourceTextbookTitle(tbTitle)
                .adminAuditStatus(q.getAdminAuditStatus())
                .rejectReason(q.getRejectReason())
                .creatorName(creatorName)
                .createdAt(q.getCreatedAt())
                .build();
    }
}