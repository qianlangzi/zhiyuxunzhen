package com.zhiyu.controller.admin;

import com.zhiyu.common.R;
import com.zhiyu.service.UserImportService;
import com.zhiyu.vo.ImportResultVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/**
 * 学生账号 Excel 批量导入（PRD 4.14）
 * 路径 /api/v1/users/import 不在 /admin/ 前缀下，权限在 Service 层校验
 */
@Tag(name = "用户管理-批量导入")
@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
public class UserImportController {

    private final UserImportService userImportService;

    @Operation(summary = "学生账号 Excel 批量导入")
    @PostMapping("/import")
    public R<ImportResultVO> importStudents(@RequestParam("file") MultipartFile file) {
        return R.ok(userImportService.importStudents(file));
    }
}
