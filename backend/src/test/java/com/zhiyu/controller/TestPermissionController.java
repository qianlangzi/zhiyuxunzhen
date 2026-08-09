package com.zhiyu.controller;

import com.zhiyu.common.R;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 权限拦截器集成测试专用 Controller
 * 提供各角色路径前缀的测试端点，仅用于测试 PermissionInterceptor 的 RBAC 逻辑
 *
 * 注意：端点路径必须与 PermissionInterceptor 中的精确匹配字符串完全一致：
 *   /api/v1/admin/users/import (POST) — 教学秘书(2)/管理员(4)
 *   /api/v1/admin/dashboard    (GET)  — 教研室主任(3)/管理员(4)/运维(5)
 */
@RestController
@RequestMapping("/api/v1")
public class TestPermissionController {

    @GetMapping("/admin/test")
    public R<String> adminTest() {
        return R.ok("ok");
    }

    /** 精确端点：POST /admin/users/import — 教学秘书(2)/管理员(4) 可访问 */
    @PostMapping("/admin/users/import")
    public R<String> adminUsersImport() {
        return R.ok("ok");
    }

    /** 精确端点：GET /admin/dashboard — 教研室主任(3)/管理员(4)/运维(5) 可访问 */
    @GetMapping("/admin/dashboard")
    public R<String> adminDashboard() {
        return R.ok("ok");
    }

    @GetMapping("/teacher/test")
    public R<String> teacherGet() {
        return R.ok("ok");
    }

    @PostMapping("/teacher/test")
    public R<String> teacherPost() {
        return R.ok("ok");
    }

    @GetMapping("/student/test")
    public R<String> studentTest() {
        return R.ok("ok");
    }

    @GetMapping("/case-market/test")
    public R<String> caseMarketTest() {
        return R.ok("ok");
    }
}
