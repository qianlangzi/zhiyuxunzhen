package com.zhiyu.controller.student;

import com.zhiyu.common.R;
import com.zhiyu.service.StudentWeaknessService;
import com.zhiyu.vo.StudentWeaknessVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 学生端-薄弱知识点接口（PRD 8.9）
 */
@Tag(name = "学生-薄弱知识点")
@RestController
@RequestMapping("/api/v1/student/weaknesses")
@RequiredArgsConstructor
public class StudentWeaknessController {

    private final StudentWeaknessService studentWeaknessService;

    @Operation(summary = "我的薄弱知识点列表（按掌握度升序）")
    @GetMapping
    public R<List<StudentWeaknessVO>> list() {
        return R.ok(studentWeaknessService.myWeaknesses());
    }
}
