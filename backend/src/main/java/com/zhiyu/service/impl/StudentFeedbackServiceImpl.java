package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.entity.StudentFeedback;
import com.zhiyu.entity.UserActionLog;
import com.zhiyu.mapper.StudentFeedbackMapper;
import com.zhiyu.mapper.UserActionLogMapper;
import com.zhiyu.service.StudentFeedbackService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

/**
 * 学生反馈与试用埋点服务实现（P2-3）
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class StudentFeedbackServiceImpl implements StudentFeedbackService {

    private final StudentFeedbackMapper feedbackMapper;
    private final UserActionLogMapper actionLogMapper;

    @Override
    public Long submit(String category, Integer rating, String content) {
        Long studentId = UserContext.requireUserId();
        StudentFeedback f = new StudentFeedback();
        f.setStudentId(studentId);
        f.setCategory(StringUtils.hasText(category) ? category : "general");
        f.setRating(rating == null ? 0 : Math.max(0, Math.min(5, rating)));
        f.setContent(StringUtils.hasText(content) ? content : "");
        f.setStatus(0);
        feedbackMapper.insert(f);
        log.info("feedback submitted: student={} category={} rating={}", studentId, f.getCategory(), f.getRating());
        return f.getId();
    }

    @Override
    public PageResult<StudentFeedback> myFeedback(Integer pageNum, Integer pageSize) {
        Long studentId = UserContext.requireUserId();
        Page<StudentFeedback> page = new Page<>(pageNum, pageSize);
        LambdaQueryWrapper<StudentFeedback> wrapper = new LambdaQueryWrapper<StudentFeedback>()
                .eq(StudentFeedback::getStudentId, studentId)
                .orderByDesc(StudentFeedback::getCreatedAt);
        feedbackMapper.selectPage(page, wrapper);
        return PageResult.of(page);
    }

    @Override
    public void track(String action, String detail) {
        try {
            var user = UserContext.get();
            if (user == null || user.getUserId() == null) {
                return;
            }
            UserActionLog logRow = new UserActionLog();
            logRow.setUserId(user.getUserId());
            logRow.setRole(user.getRole() != null && user.getRole() == 1 ? "teacher" : "student");
            logRow.setAction(StringUtils.hasText(action) ? action : "unknown");
            logRow.setDetail(detail == null ? "" : detail);
            actionLogMapper.insert(logRow);
        } catch (Exception e) {
            // 埋点失败不影响主流程
            log.warn("track action failed: {}", e.getMessage());
        }
    }
}
