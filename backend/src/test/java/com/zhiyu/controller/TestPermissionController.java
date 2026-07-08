package com.zhiyu.controller;

import com.zhiyu.common.R;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 权限拦截器集成测试专用 Controller
 * 提供各角色路径前缀的测试端点，仅用于测试 PermissionInterceptor 的 RBAC 逻辑
 */
@RestController
@RequestMapping("/api/v1")
public class TestPermissionController {

    @GetMapping("/admin/test")
    public R<String> adminTest() {
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
