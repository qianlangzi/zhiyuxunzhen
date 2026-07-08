package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.entity.SpCaseConfig;
import com.zhiyu.entity.StudentMistakes;
import com.zhiyu.mapper.SpCaseConfigMapper;
import com.zhiyu.mapper.StudentMistakesMapper;
import com.zhiyu.service.StudentMistakeService;
import com.zhiyu.vo.MistakeVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.stream.Collectors;

/**
 * 学生错题本服务实现（PRD 4.11）
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class StudentMistakeServiceImpl implements StudentMistakeService {

    private final StudentMistakesMapper mistakesMapper;
    private final SpCaseConfigMapper caseMapper;

    @Override
    public PageResult<MistakeVO> myMistakes(Integer pageNum, Integer pageSize, String mistakeType) {
        Long studentId = UserContext.requireUserId();
        Page<StudentMistakes> page = new Page<>(pageNum, pageSize);
        LambdaQueryWrapper<StudentMistakes> wrapper = new LambdaQueryWrapper<StudentMistakes>()
                .eq(StudentMistakes::getStudentId, studentId)
                .eq(StringUtils.hasText(mistakeType), StudentMistakes::getMistakeType, mistakeType)
                .orderByDesc(StudentMistakes::getCreatedAt);
        mistakesMapper.selectPage(page, wrapper);

        List<StudentMistakes> records = page.getRecords();
        // 批量补全病例标题
        List<Long> caseIds = records.stream()
                .map(StudentMistakes::getCaseId)
                .filter(Objects::nonNull)
                .distinct()
                .collect(Collectors.toList());
        Map<Long, String> titleMap = new HashMap<>();
        if (!caseIds.isEmpty()) {
            for (SpCaseConfig c : caseMapper.selectList(
                    new LambdaQueryWrapper<SpCaseConfig>().in(SpCaseConfig::getId, caseIds))) {
                titleMap.put(c.getId(), c.getTitle());
            }
        }

        List<MistakeVO> list = records.stream().map(m -> MistakeVO.builder()
                .id(m.getId())
                .caseId(m.getCaseId())
                .caseTitle(m.getCaseId() == null ? null : titleMap.get(m.getCaseId()))
                .sessionId(m.getSessionId())
                .mistakeType(m.getMistakeType())
                .knowledgeTag(m.getKnowledgeTag())
                .studentAnswer(m.getStudentAnswer())
                .standardAnswer(m.getStandardAnswer())
                .evidenceJson(m.getEvidenceJson())
                .resolvedStatus(m.getResolvedStatus())
                .createdAt(m.getCreatedAt())
                .build()).collect(Collectors.toList());
        return PageResult.of(page, list);
    }
}
