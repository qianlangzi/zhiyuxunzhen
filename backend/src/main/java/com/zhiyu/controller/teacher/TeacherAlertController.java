package com.zhiyu.controller.teacher;

import com.zhiyu.common.R;
import com.zhiyu.service.TeacherAlertService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * 教师端学情预警中心（助教：学情精准诊断）
 * Rule-first 规则引擎 + AI 干预建议 + 站内信推送
 */
@RestController
@RequestMapping("/api/v1/teacher/alert")
@RequiredArgsConstructor
public class TeacherAlertController {

    private final TeacherAlertService alertService;

    /** 班级预警总览 */
    @GetMapping("/overview")
    public R<Map<String, Object>> overview() {
        return R.ok(alertService.overview());
    }

    /** 预警学生列表 */
    @GetMapping("/list")
    public R<List<Map<String, Object>>> list(
            @RequestParam(required = false) Long classId,
            @RequestParam(required = false) Integer level) {
        return R.ok(alertService.list(classId, level));
    }

    /** 单个学生预警详情 */
    @GetMapping("/{studentId}")
    public R<Map<String, Object>> detail(@PathVariable Long studentId) {
        return R.ok(alertService.detail(studentId));
    }

    /** 生成 AI 干预建议 */
    @PostMapping("/{studentId}/intervene")
    public R<Map<String, Object>> intervene(@PathVariable Long studentId) {
        return R.ok(alertService.intervene(studentId));
    }

    /** 标记预警已处理 */
    @PostMapping("/{alertId}/resolve")
    public R<Void> resolve(@PathVariable Long alertId) {
        alertService.markResolved(alertId);
        return R.ok();
    }

    /** 手动触发全量扫描 */
    @PostMapping("/scan")
    public R<Void> scan() {
        alertService.scan();
        return R.ok();
    }
}
