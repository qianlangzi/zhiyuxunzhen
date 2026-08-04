package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.entity.StudentWeakness;
import com.zhiyu.mapper.StudentWeaknessMapper;
import com.zhiyu.service.StudentWeaknessService;
import com.zhiyu.vo.StudentWeaknessVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

/**
 * 学生薄弱知识点服务实现（PRD 8.9）
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class StudentWeaknessServiceImpl implements StudentWeaknessService {

    private final StudentWeaknessMapper weaknessMapper;

    @Override
    public List<StudentWeaknessVO> myWeaknesses() {
        Long studentId = UserContext.requireUserId();
        List<StudentWeakness> records = weaknessMapper.selectList(
                new LambdaQueryWrapper<StudentWeakness>()
                        .eq(StudentWeakness::getStudentId, studentId)
                        .orderByAsc(StudentWeakness::getWeaknessScore));
        return records.stream().map(w -> StudentWeaknessVO.builder()
                .id(w.getId())
                .knowledgeTag(w.getKnowledgeTag())
                .weaknessScore(w.getWeaknessScore())
                .evidenceCount(w.getEvidenceCount())
                .recommendedPathJson(w.getRecommendedPathJson())
                .lastUpdated(w.getLastUpdated())
                .build()).collect(Collectors.toList());
    }
}
