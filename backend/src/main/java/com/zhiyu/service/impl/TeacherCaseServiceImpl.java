package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.entity.Assignment;
import com.zhiyu.entity.SpCaseConfig;
import com.zhiyu.mapper.AssignmentMapper;
import com.zhiyu.mapper.SpCaseConfigMapper;
import com.zhiyu.service.TeacherCaseService;
import com.zhiyu.service.dto.CaseCreateDTO;
import com.zhiyu.service.dto.CaseUpdateDTO;
import com.zhiyu.vo.CasePreviewVO;
import com.zhiyu.vo.TeacherCaseListVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.math.BigDecimal;
import java.util.List;
import java.util.stream.Collectors;

/**
 * 教师病例服务实现（PRD 4.1）
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TeacherCaseServiceImpl implements TeacherCaseService {

    private final SpCaseConfigMapper caseMapper;
    private final AssignmentMapper assignmentMapper;

    @Override
    public Long create(CaseCreateDTO req) {
        Long creatorId = UserContext.requireUserId();
        SpCaseConfig c = new SpCaseConfig();
        c.setCreatorId(creatorId);
        c.setTitle(req.getTitle());
        c.setDepartment(req.getDepartment());
        c.setDifficulty(req.getDifficulty());
        c.setPatientProfile(req.getPatientProfile());
        c.setHiddenDisease(req.getHiddenDisease());
        c.setStandardPathJson(req.getStandardPathJson());
        c.setPresetExams(req.getPresetExams());
        c.setKnowledgeTags(req.getKnowledgeTags());
        c.setIsPublic(false);
        c.setReferenceCount(0);
        c.setRatingAvg(BigDecimal.ZERO);
        c.setAdminAuditStatus(0);
        c.setVersion(1);
        c.setStatus(0);
        caseMapper.insert(c);
        log.info("教师{}创建病例{}", creatorId, c.getId());
        return c.getId();
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void update(Long id, CaseUpdateDTO req) {
        Long userId = UserContext.requireUserId();
        SpCaseConfig c = caseMapper.selectById(id);
        if (c == null) {
            throw new BizException(ResultCode.CASE_NOT_FOUND);
        }
        if (!userId.equals(c.getCreatorId())) {
            throw new BizException(ResultCode.FORBIDDEN);
        }
        // 已被作业引用：仅当尝试修改核心诊断字段时禁止（PRD 9.1）
        // 核心诊断字段：hiddenDisease、standardPathJson、presetExams、patientProfile
        Long refCount = assignmentMapper.selectCount(
                new LambdaQueryWrapper<Assignment>().eq(Assignment::getCaseId, id));
        if (refCount != null && refCount > 0 && isCoreFieldModified(req, c)) {
            throw new BizException(ResultCode.CASE_REFERENCED);
        }
        c.setTitle(req.getTitle());
        c.setDepartment(req.getDepartment());
        c.setDifficulty(req.getDifficulty());
        c.setPatientProfile(req.getPatientProfile());
        c.setHiddenDisease(req.getHiddenDisease());
        c.setStandardPathJson(req.getStandardPathJson());
        c.setPresetExams(req.getPresetExams());
        c.setKnowledgeTags(req.getKnowledgeTags());
        c.setVersion(c.getVersion() == null ? 1 : c.getVersion() + 1);
        caseMapper.updateById(c);
        log.info("教师{}更新病例{}，version={}", userId, id, c.getVersion());
    }

    @Override
    public PageResult<TeacherCaseListVO> myCases(Integer pageNum, Integer pageSize, String title, String department) {
        Long userId = UserContext.requireUserId();
        Page<SpCaseConfig> page = new Page<>(pageNum, pageSize);
        LambdaQueryWrapper<SpCaseConfig> wrapper = new LambdaQueryWrapper<SpCaseConfig>()
                .eq(SpCaseConfig::getCreatorId, userId)
                .like(StringUtils.hasText(title), SpCaseConfig::getTitle, title)
                .eq(StringUtils.hasText(department), SpCaseConfig::getDepartment, department)
                .orderByDesc(SpCaseConfig::getCreatedAt);
        caseMapper.selectPage(page, wrapper);

        List<TeacherCaseListVO> list = page.getRecords().stream().map(c -> TeacherCaseListVO.builder()
                .id(c.getId())
                .title(c.getTitle())
                .department(c.getDepartment())
                .difficulty(c.getDifficulty())
                .status(c.getStatus())
                .adminAuditStatus(c.getAdminAuditStatus())
                .referenceCount(c.getReferenceCount())
                .ratingAvg(c.getRatingAvg())
                .isPublic(c.getIsPublic())
                .createdAt(c.getCreatedAt())
                .build()).collect(Collectors.toList());
        return PageResult.of(page, list);
    }

    @Override
    public CasePreviewVO preview(Long id) {
        Long userId = UserContext.requireUserId();
        SpCaseConfig c = caseMapper.selectById(id);
        if (c == null) {
            throw new BizException(ResultCode.CASE_NOT_FOUND);
        }
        if (!userId.equals(c.getCreatorId())) {
            throw new BizException(ResultCode.FORBIDDEN);
        }
        return CasePreviewVO.builder()
                .id(c.getId())
                .title(c.getTitle())
                .department(c.getDepartment())
                .difficulty(c.getDifficulty())
                .patientProfile(c.getPatientProfile())
                .hiddenDisease(c.getHiddenDisease())
                .standardPathJson(c.getStandardPathJson())
                .presetExams(c.getPresetExams())
                .knowledgeTags(c.getKnowledgeTags())
                .isPublic(c.getIsPublic())
                .sourceCaseId(c.getSourceCaseId())
                .referenceCount(c.getReferenceCount())
                .ratingAvg(c.getRatingAvg())
                .adminAuditStatus(c.getAdminAuditStatus())
                .version(c.getVersion())
                .status(c.getStatus())
                .createdAt(c.getCreatedAt())
                .updatedAt(c.getUpdatedAt())
                .build();
    }

    /**
     * 判断请求是否尝试修改核心诊断字段（PRD 9.1）
     * 核心字段：hiddenDisease、standardPathJson、presetExams、patientProfile
     */
    private boolean isCoreFieldModified(CaseUpdateDTO req, SpCaseConfig c) {
        return isChanged(req.getHiddenDisease(), c.getHiddenDisease())
                || isChanged(req.getStandardPathJson(), c.getStandardPathJson())
                || isChanged(req.getPresetExams(), c.getPresetExams())
                || isChanged(req.getPatientProfile(), c.getPatientProfile());
    }

    /** 判断字符串字段是否发生实质性变更（请求值非空且与当前值不同） */
    private boolean isChanged(String reqVal, String curVal) {
        return reqVal != null && !reqVal.equals(curVal);
    }
}
