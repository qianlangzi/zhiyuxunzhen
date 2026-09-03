package com.zhiyu.controller.common;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.zhiyu.common.R;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.entity.SysNotification;
import com.zhiyu.mapper.SysNotificationMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * 站内信通知（预警推送/作业提醒/系统消息）
 * 教师端查看预警站内信、标记已读。
 */
@RestController
@RequestMapping("/api/v1/notifications")
@RequiredArgsConstructor
public class NotificationController {

    private final SysNotificationMapper notificationMapper;

    /** 我的通知列表（未读优先） */
    @GetMapping
    public R<List<Map<String, Object>>> list() {
        Long userId = UserContext.requireUserId();
        List<SysNotification> list = notificationMapper.selectList(
                new LambdaQueryWrapper<SysNotification>()
                        .eq(SysNotification::getRecipientId, userId)
                        .orderByAsc(SysNotification::getIsRead)
                        .orderByDesc(SysNotification::getCreatedAt)
                        .last("LIMIT 50"));
        return R.ok(list.stream().map(n -> Map.<String, Object>of(
                "id", n.getId(),
                "notifyType", n.getNotifyType(),
                "title", n.getTitle(),
                "content", n.getContent(),
                "refId", n.getRefId(),
                "isRead", n.getIsRead(),
                "createdAt", n.getCreatedAt()
        )).toList());
    }

    /** 未读数 */
    @GetMapping("/unread-count")
    public R<Long> unreadCount() {
        Long userId = UserContext.requireUserId();
        Long count = notificationMapper.selectCount(
                new LambdaQueryWrapper<SysNotification>()
                        .eq(SysNotification::getRecipientId, userId)
                        .eq(SysNotification::getIsRead, 0));
        return R.ok(count);
    }

    /** 标记已读 */
    @PostMapping("/{id}/read")
    public R<Void> markRead(@PathVariable Long id) {
        Long userId = UserContext.requireUserId();
        SysNotification n = notificationMapper.selectById(id);
        if (n != null && userId.equals(n.getRecipientId())) {
            n.setIsRead(1);
            notificationMapper.updateById(n);
        }
        return R.ok();
    }

    /** 全部已读 */
    @PostMapping("/read-all")
    public R<Void> markAllRead() {
        Long userId = UserContext.requireUserId();
        List<SysNotification> list = notificationMapper.selectList(
                new LambdaQueryWrapper<SysNotification>()
                        .eq(SysNotification::getRecipientId, userId)
                        .eq(SysNotification::getIsRead, 0));
        for (SysNotification n : list) {
            n.setIsRead(1);
            notificationMapper.updateById(n);
        }
        return R.ok();
    }
}
