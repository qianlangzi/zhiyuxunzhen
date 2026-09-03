package com.zhiyu.controller.student;

import com.zhiyu.common.R;
import com.zhiyu.service.TeachingClassService;
import com.zhiyu.service.dto.TeachingClassJoinDTO;
import com.zhiyu.vo.MyClassVO;
import com.zhiyu.vo.StudentClassDetailVO;
import com.zhiyu.vo.TeachingClassVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * 学生端-班级（扫码/邀请码加入班级，查看我的课程，查看班级闭环内容）
 */
@Tag(name = "学生-班级")
@RestController
@RequestMapping("/api/v1/student/classes")
@RequiredArgsConstructor
public class StudentClassController {

    private final TeachingClassService teachingClassService;

    @Operation(summary = "通过邀请码加入班级")
    @PostMapping("/join")
    public R<TeachingClassVO> join(@Valid @RequestBody TeachingClassJoinDTO req) {
        return R.ok(teachingClassService.joinByCode(req));
    }

    @Operation(summary = "我的课程（已加入的班级列表）")
    @GetMapping("/my-classes")
    public R<List<MyClassVO>> myClasses() {
        return R.ok(teachingClassService.myStudentClasses());
    }

    @Operation(summary = "班级详情（教师分享的资料与作业，仅该班成员可见）")
    @GetMapping("/{classId}")
    public R<StudentClassDetailVO> detail(@PathVariable Long classId) {
        return R.ok(teachingClassService.studentClassBase(classId));
    }
}