package com.zhiyu.controller.internal;

import com.zhiyu.common.R;
import com.zhiyu.service.InternalCallbackService;
import com.zhiyu.service.dto.internal.MistakesSyncDTO;
import com.zhiyu.service.dto.internal.ModelEventLogDTO;
import com.zhiyu.service.dto.internal.ReviewCallbackDTO;
import com.zhiyu.service.dto.internal.SessionArchiveDTO;
import com.zhiyu.service.dto.internal.WeaknessSyncDTO;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 内部回调接口（PRD 9.4）
 * 路径前缀 /api/internal，由 InternalApiInterceptor 用 X-Internal-Token 头鉴权，不走 JWT
 */
@Tag(name = "内部回调-AI中台")
@RestController
@RequestMapping("/api/internal")
@RequiredArgsConstructor
public class InternalCallbackController {

    private final InternalCallbackService internalCallbackService;

    @Operation(summary = "归档问诊会话（更新状态、评分、报告、思维树）")
    @PostMapping("/session/archive")
    public R<Void> archiveSession(@Valid @RequestBody SessionArchiveDTO dto) {
        internalCallbackService.archiveSession(dto);
        return R.ok();
    }

    @Operation(summary = "AI批阅结果回调（写入批阅记录，更新作业实例状态为待复核）")
    @PostMapping("/review/callback")
    public R<Void> reviewCallback(@Valid @RequestBody ReviewCallbackDTO dto) {
        internalCallbackService.reviewCallback(dto);
        return R.ok();
    }

    @Operation(summary = "同步错题本（批量插入）")
    @PostMapping("/mistakes/sync")
    public R<Void> syncMistakes(@RequestBody MistakesSyncDTO dto) {
        internalCallbackService.syncMistakes(dto);
        return R.ok();
    }

    @Operation(summary = "同步薄弱知识点（upsert）")
    @PostMapping("/weakness/sync")
    public R<Void> syncWeakness(@RequestBody WeaknessSyncDTO dto) {
        internalCallbackService.syncWeakness(dto);
        return R.ok();
    }

    @Operation(summary = "记录模型异常和降级事件")
    @PostMapping("/model-event/log")
    public R<Void> logModelEvent(@RequestBody ModelEventLogDTO dto) {
        internalCallbackService.logModelEvent(dto);
        return R.ok();
    }
}
