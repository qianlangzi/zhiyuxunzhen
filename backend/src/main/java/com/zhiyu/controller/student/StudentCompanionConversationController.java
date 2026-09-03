package com.zhiyu.controller.student;

import com.zhiyu.common.R;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.entity.CompanionConversation;
import com.zhiyu.entity.CompanionMessage;
import com.zhiyu.service.CompanionConversationService;
import com.zhiyu.service.dto.CompanionConversationCreateRequest;
import com.zhiyu.service.dto.CompanionConversationRenameRequest;
import com.zhiyu.service.dto.CompanionMessageCreateRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 学生 · AI 学伴会话历史管理（P1-2）
 * 会话 CRUD + 消息读写；与 synchronized/stream 对话接口并列，路径
 * 约定与移动端 StudentApi 完全一致：
 *   GET    /conversations            会话列表（分页）
 *   POST   /conversations            新建会话
 *   PUT    /conversations/{id}       重命名
 *   DELETE /conversations/{id}       删除
 *   GET    /conversations/{id}/messages     消息列表（分页）
 *   POST   /conversations/{id}/messages     写入消息
 */
@Tag(name = "学生-AI学伴会话历史")
@RestController
@RequestMapping("/api/v1/student/companion/conversations")
@RequiredArgsConstructor
public class StudentCompanionConversationController {

    private final CompanionConversationService companionConversationService;

    @Operation(summary = "AI 学伴会话列表（分页）")
    @GetMapping
    public R<PageResult<CompanionConversation>> list(
            @RequestParam(defaultValue = "1") int pageNum,
            @RequestParam(defaultValue = "10") int pageSize) {
        return R.ok(companionConversationService.list(pageNum, pageSize));
    }

    @Operation(summary = "新建 AI 学伴会话")
    @PostMapping
    public R<CompanionConversation> create(@Valid @RequestBody CompanionConversationCreateRequest req) {
        return R.ok(companionConversationService.create(req.getTitle()));
    }

    @Operation(summary = "重命名 AI 学伴会话")
    @PutMapping("/{id}")
    public R<CompanionConversation> rename(@PathVariable Long id,
                                           @Valid @RequestBody CompanionConversationRenameRequest req) {
        return R.ok(companionConversationService.rename(id, req.getTitle()));
    }

    @Operation(summary = "删除 AI 学伴会话（逻辑删除）")
    @DeleteMapping("/{id}")
    public R<Void> delete(@PathVariable Long id) {
        companionConversationService.delete(id);
        return R.ok();
    }

    @Operation(summary = "AI 学伴会话消息列表（分页）")
    @GetMapping("/{id}/messages")
    public R<PageResult<CompanionMessage>> listMessages(
            @PathVariable("id") Long conversationId,
            @RequestParam(defaultValue = "1") int pageNum,
            @RequestParam(defaultValue = "20") int pageSize) {
        return R.ok(companionConversationService.listMessages(conversationId, pageNum, pageSize));
    }

    @Operation(summary = "写入 AI 学伴会话消息")
    @PostMapping("/{id}/messages")
    public R<CompanionMessage> addMessage(@PathVariable("id") Long conversationId,
                                          @Valid @RequestBody CompanionMessageCreateRequest req) {
        // 兼容 BadRequest 风格重试/异常提示
        try {
            return R.ok(companionConversationService.addMessage(
                    conversationId, req.getSender(), req.getContent(), req.getImageUrl()));
        } catch (BizException e) {
            return R.fail(e.getCode(), e.getMessage());
        } catch (Exception e) {
            return R.fail(ResultCode.INTERNAL_ERROR.getCode(), "消息保存失败");
        }
    }
}