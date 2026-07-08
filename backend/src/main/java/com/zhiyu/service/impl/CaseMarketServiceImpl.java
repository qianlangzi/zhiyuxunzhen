package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.entity.SpCaseConfig;
import com.zhiyu.entity.SysUser;
import com.zhiyu.mapper.SpCaseConfigMapper;
import com.zhiyu.mapper.SysUserMapper;
import com.zhiyu.service.CaseMarketService;
import com.zhiyu.vo.CaseMarketListVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.stream.Collectors;

/**
 * 病例广场服务实现（PRD 4.2）
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class CaseMarketServiceImpl implements CaseMarketService {

    private final SpCaseConfigMapper caseMapper;
    private final SysUserMapper userMapper;

    @Override
    public PageResult<CaseMarketListVO> list(Integer pageNum, Integer pageSize, String department,
                                             Integer difficulty, String sortBy, String order) {
        Page<SpCaseConfig> page = new Page<>(pageNum, pageSize);
        LambdaQueryWrapper<SpCaseConfig> wrapper = new LambdaQueryWrapper<SpCaseConfig>()
                .eq(SpCaseConfig::getIsPublic, true)
                .eq(SpCaseConfig::getAdminAuditStatus, 2)
                .eq(SpCaseConfig::getStatus, 1)
                .eq(StringUtils.hasText(department), SpCaseConfig::getDepartment, department)
                .eq(difficulty != null, SpCaseConfig::getDifficulty, difficulty);

        boolean asc = "asc".equalsIgnoreCase(order);
        String sb = (sortBy == null || sortBy.isBlank()) ? "createdAt" : sortBy;
        switch (sb) {
            case "rating", "ratingAvg" -> wrapper.orderBy(true, asc, SpCaseConfig::getRatingAvg);
            case "reference", "referenceCount" -> wrapper.orderBy(true, asc, SpCaseConfig::getReferenceCount);
            case "difficulty" -> wrapper.orderBy(true, asc, SpCaseConfig::getDifficulty);
            case "createdAt" -> wrapper.orderBy(true, asc, SpCaseConfig::getCreatedAt);
            default -> wrapper.orderBy(true, false, SpCaseConfig::getCreatedAt);
        }
        caseMapper.selectPage(page, wrapper);

        List<SpCaseConfig> records = page.getRecords();
        // 批量补全创建者姓名
        List<Long> creatorIds = records.stream()
                .map(SpCaseConfig::getCreatorId)
                .filter(Objects::nonNull)
                .distinct()
                .collect(Collectors.toList());
        Map<Long, String> nameMap = new HashMap<>();
        if (!creatorIds.isEmpty()) {
            List<SysUser> users = userMapper.selectList(
                    new LambdaQueryWrapper<SysUser>().in(SysUser::getId, creatorIds));
            for (SysUser u : users) {
                nameMap.put(u.getId(), u.getRealName());
            }
        }

        List<CaseMarketListVO> list = records.stream().map(c -> CaseMarketListVO.builder()
                .id(c.getId())
                .title(c.getTitle())
                .department(c.getDepartment())
                .difficulty(c.getDifficulty())
                .ratingAvg(c.getRatingAvg())
                .referenceCount(c.getReferenceCount())
                .creatorName(nameMap.getOrDefault(c.getCreatorId(), ""))
                .knowledgeTags(c.getKnowledgeTags())
                .createdAt(c.getCreatedAt())
                .build()).collect(Collectors.toList());
        return PageResult.of(page, list);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public Long quote(Long caseId) {
        // 仅教师可引用病例
        UserContext.requireRole(1);
        Long teacherId = UserContext.requireUserId();

        SpCaseConfig src = caseMapper.selectById(caseId);
        if (src == null) {
            throw new BizException(ResultCode.CASE_NOT_FOUND);
        }
        if (!Boolean.TRUE.equals(src.getIsPublic()) || src.getAdminAuditStatus() == null || src.getAdminAuditStatus() != 2) {
            throw new BizException(ResultCode.CASE_NOT_QUOTABLE);
        }

        // 复制为当前教师的独立副本
        SpCaseConfig copy = new SpCaseConfig();
        copy.setCreatorId(teacherId);
        copy.setSourceCaseId(caseId);
        copy.setTitle(src.getTitle());
        copy.setDepartment(src.getDepartment());
        copy.setDifficulty(src.getDifficulty());
        copy.setPatientProfile(src.getPatientProfile());
        copy.setHiddenDisease(src.getHiddenDisease());
        copy.setStandardPathJson(src.getStandardPathJson());
        copy.setPresetExams(src.getPresetExams());
        copy.setKnowledgeTags(src.getKnowledgeTags());
        copy.setIsPublic(false);
        copy.setReferenceCount(0);
        copy.setRatingAvg(BigDecimal.ZERO);
        copy.setAdminAuditStatus(0);
        copy.setVersion(1);
        copy.setStatus(0);
        caseMapper.insert(copy);

        // 原病例引用量 +1（SQL 原子自增，避免并发竞态）
        caseMapper.incrementReferenceCount(caseId);

        log.info("教师{}引用病例{}为新副本{}", teacherId, caseId, copy.getId());
        return copy.getId();
    }
}
