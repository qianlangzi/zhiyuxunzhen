package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.zhiyu.entity.PracticeQuestion;
import com.zhiyu.entity.StudentMistakes;
import com.zhiyu.entity.StudentPracticeRecord;
import com.zhiyu.entity.StudentWeakness;
import com.zhiyu.mapper.PracticeQuestionMapper;
import com.zhiyu.mapper.StudentMistakesMapper;
import com.zhiyu.mapper.StudentPracticeRecordMapper;
import com.zhiyu.mapper.StudentWeaknessMapper;
import com.zhiyu.service.WeaknessAnalysisService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * 薄弱知识点推算实现（确定性统计，不依赖 LLM）。
 *
 * 掌握度推算逻辑（便于复核）：
 * 1. 刷题分量：取该知识点近 180 天刷题记录，按时间衰减加权求正确率 accuracy ∈ [0,1]；
 *    对掌握度的贡献 = 0.5 * (accuracy - 0.5)，即满分 +0.25、50% 为 0、零分 -0.25。
 * 2. 错题扣分：每条错题按时间衰减加权记为错题权重，已掌握(resolvedStatus=2)记 0.4 倍；
 *    扣分 = min(0.4, 0.08 * 错题权重)，最多扣 0.4。
 * 3. 综合：proficiency = 0.5 + 刷题贡献 - 错题扣分，再 clamp 到 [0.05, 0.98]。
 * 4. evidenceCount = 刷题次数 + 错题条数，供前端展示证据量与同分排序。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class WeaknessAnalysisServiceImpl implements WeaknessAnalysisService {

    private static final double HALF_LIFE_DAYS = 30.0;
    private static final int ANALYSIS_WINDOW_DAYS = 180;

    private final StudentWeaknessMapper weaknessMapper;
    private final StudentMistakesMapper mistakesMapper;
    private final StudentPracticeRecordMapper practiceRecordMapper;
    private final PracticeQuestionMapper questionMapper;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void refreshForStudent(Long studentId) {
        if (studentId == null) {
            return;
        }
        LocalDateTime windowStart = LocalDateTime.now().minusDays(ANALYSIS_WINDOW_DAYS);

        // 1. 刷题记录 → 按知识点聚合
        List<StudentPracticeRecord> records = practiceRecordMapper.selectList(
                new LambdaQueryWrapper<StudentPracticeRecord>()
                        .eq(StudentPracticeRecord::getStudentId, studentId)
                        .ge(StudentPracticeRecord::getAnsweredAt, windowStart));
        Map<Long, String> questionTagMap = loadQuestionTags(records);

        Map<String, ProficiencyAgg> byTag = new HashMap<>();
        for (StudentPracticeRecord r : records) {
            String tag = questionTagMap.get(r.getQuestionId());
            if (!StringUtils.hasText(tag)) {
                continue;
            }
            double weight = decayWeight(r.getAnsweredAt());
            ProficiencyAgg agg = byTag.computeIfAbsent(tag, k -> new ProficiencyAgg());
            agg.weightedTotal += weight;
            if (Boolean.TRUE.equals(r.getIsCorrect())) {
                agg.weightedCorrect += weight;
            }
            agg.evidenceCount++;
        }

        // 2. 错题本 → 扣分
        List<StudentMistakes> mistakes = mistakesMapper.selectList(
                new LambdaQueryWrapper<StudentMistakes>()
                        .eq(StudentMistakes::getStudentId, studentId)
                        .ge(StudentMistakes::getCreatedAt, windowStart));
        for (StudentMistakes m : mistakes) {
            String tag = m.getKnowledgeTag();
            if (!StringUtils.hasText(tag)) {
                continue;
            }
            double weight = decayWeight(m.getCreatedAt());
            double resolvedFactor = (m.getResolvedStatus() != null && m.getResolvedStatus() == 2) ? 0.4 : 1.0;
            ProficiencyAgg agg = byTag.computeIfAbsent(tag, k -> new ProficiencyAgg());
            agg.mistakeWeight += weight * resolvedFactor;
            agg.evidenceCount++;
        }

        // 3. 综合计算并 upsert
        for (Map.Entry<String, ProficiencyAgg> entry : byTag.entrySet()) {
            String tag = entry.getKey();
            ProficiencyAgg agg = entry.getValue();
            double accuracy = agg.weightedTotal > 0 ? agg.weightedCorrect / agg.weightedTotal : 0.5;
            double proficiency = 0.5 + 0.5 * (accuracy - 0.5)
                    - Math.min(0.4, 0.08 * agg.mistakeWeight);
            proficiency = Math.max(0.05, Math.min(0.98, proficiency));
            upsertWeakness(studentId, tag, proficiency, agg.evidenceCount);
        }

        log.info("薄弱知识点重算完成: studentId={} tags={}", studentId, byTag.size());
    }

    private Map<Long, String> loadQuestionTags(List<StudentPracticeRecord> records) {
        Map<Long, String> map = new HashMap<>();
        if (records == null || records.isEmpty()) {
            return map;
        }
        Set<Long> ids = new HashSet<>();
        for (StudentPracticeRecord r : records) {
            if (r.getQuestionId() != null) {
                ids.add(r.getQuestionId());
            }
        }
        if (ids.isEmpty()) {
            return map;
        }
        List<PracticeQuestion> questions = questionMapper.selectBatchIds(ids);
        for (PracticeQuestion q : questions) {
            if (q != null) {
                map.put(q.getId(), q.getKnowledgeTag());
            }
        }
        return map;
    }

    private void upsertWeakness(Long studentId, String tag, double proficiency, int evidenceCount) {
        StudentWeakness existing = weaknessMapper.selectOne(
                new LambdaQueryWrapper<StudentWeakness>()
                        .eq(StudentWeakness::getStudentId, studentId)
                        .eq(StudentWeakness::getKnowledgeTag, tag));
        BigDecimal score = BigDecimal.valueOf(Math.round(proficiency * 100.0) / 100.0);
        if (existing != null) {
            existing.setWeaknessScore(score);
            existing.setEvidenceCount(evidenceCount);
            existing.setLastUpdated(LocalDateTime.now());
            weaknessMapper.updateById(existing);
        } else {
            StudentWeakness weakness = new StudentWeakness();
            weakness.setStudentId(studentId);
            weakness.setKnowledgeTag(tag);
            weakness.setWeaknessScore(score);
            weakness.setEvidenceCount(evidenceCount);
            weakness.setLastUpdated(LocalDateTime.now());
            weaknessMapper.insert(weakness);
        }
    }

    /** 时间衰减权重：距今越近权重越高，半衰期 30 天 */
    private double decayWeight(LocalDateTime at) {
        if (at == null) {
            return 0.5;
        }
        long days = ChronoUnit.DAYS.between(at, LocalDateTime.now());
        if (days < 0) {
            days = 0;
        }
        return Math.exp(-days / HALF_LIFE_DAYS);
    }

    /** 单个知识点聚合的中间量 */
    private static class ProficiencyAgg {
        double weightedTotal;
        double weightedCorrect;
        double mistakeWeight;
        int evidenceCount;
    }
}