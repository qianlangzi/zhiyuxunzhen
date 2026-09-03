package com.zhiyu.controller.admin;

import com.zhiyu.common.R;
import com.zhiyu.common.param.PageParam;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.AdminService;
import com.zhiyu.service.PdfCoverService;
import com.zhiyu.vo.TextbookAdminVO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * 管理端-教材管理（教材审核看板 + 触发向量化入库 + 上/下架）
 * 闭环：教师上传教材 → 管理端触发向量化入库 → AI 异步入库 → 回调更新状态 → 学生/教师端 RAG 检索
 */
@Tag(name = "管理端-教材管理")
@RestController
@RequestMapping("/api/v1/admin/textbooks")
@RequiredArgsConstructor
public class AdminTextbookController {

    private final AdminService adminService;
    private final PdfCoverService pdfCoverService;

    @Operation(summary = "教材列表（含入库状态、上传教师）")
    @GetMapping
    public R<PageResult<TextbookAdminVO>> list(PageParam param) {
        return R.ok(adminService.textbookList(param));
    }

    @Operation(summary = "触发教材向量化入库（异步，完成回调更新状态）")
    @PostMapping("/{textbookId}/ingest")
    public R<Map<String, Object>> ingest(@PathVariable Long textbookId) {
        return R.ok(adminService.triggerTextbookIngest(textbookId));
    }

    @Operation(summary = "查询教材最近一次入库任务详情（任务 ID/尝试次数/错误信息）")
    @GetMapping("/{textbookId}/ingest-task")
    public R<Map<String, Object>> ingestTask(@PathVariable Long textbookId) {
        return R.ok(adminService.textbookIngestTask(textbookId));
    }

    @Operation(summary = "教材上架/下架切换")
    @PostMapping("/{textbookId}/toggle-status")
    public R<Void> toggleStatus(@PathVariable Long textbookId) {
        adminService.toggleTextbook(textbookId);
        return R.ok();
    }

    @Operation(summary = "为缺失封面的教材批量生成封面（PDF 首页渲染，同步执行）")
    @PostMapping("/backfill-covers")
    public R<Integer> backfillCovers() {
        return R.ok(pdfCoverService.backfillAllMissingCovers());
    }
}