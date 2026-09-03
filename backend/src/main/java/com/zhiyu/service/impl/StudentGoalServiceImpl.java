package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.entity.StudentGoal;
import com.zhiyu.mapper.StudentGoalMapper;
import com.zhiyu.service.StudentGoalService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

import java.time.LocalDate;

/**
 * 学生学习目标服务实现（P2-1）
 */
@Service
@RequiredArgsConstructor
public class StudentGoalServiceImpl implements StudentGoalService {

    private final StudentGoalMapper goalMapper;

    @Override
    public StudentGoal myGoal() {
        Long studentId = UserContext.requireUserId();
        return goalMapper.selectOne(new LambdaQueryWrapper<StudentGoal>()
                .eq(StudentGoal::getStudentId, studentId)
                .orderByDesc(StudentGoal::getUpdatedAt)
                .last("LIMIT 1"));
    }

    @Override
    public Long upsert(String title, String targetMetric, String targetDate) {
        Long studentId = UserContext.requireUserId();
        StudentGoal existing = goalMapper.selectOne(new LambdaQueryWrapper<StudentGoal>()
                .eq(StudentGoal::getStudentId, studentId)
                .last("LIMIT 1"));
        if (existing == null) {
            existing = new StudentGoal();
            existing.setStudentId(studentId);
            existing.setStatus(0);
        }
        existing.setTitle(StringUtils.hasText(title) ? title : "");
        existing.setTargetMetric(StringUtils.hasText(targetMetric) ? targetMetric : "");
        existing.setTargetDate(StringUtils.hasText(targetDate) ? LocalDate.parse(targetDate) : null);
        if (existing.getId() == null) {
            goalMapper.insert(existing);
        } else {
            goalMapper.updateById(existing);
        }
        return existing.getId();
    }
}
