package com.zhiyu.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;
import lombok.EqualsAndHashCode;

/**
 * 站内信通知（预警推送/作业提醒/系统消息）
 */
@Data
@EqualsAndHashCode(callSuper = true)
@TableName("sys_notification")
public class SysNotification extends BaseEntity {

    private Long recipientId;

    /** alert/assignment/review/system */
    private String notifyType;

    private String title;

    private String content;

    /** 关联对象 ID（如预警ID/作业ID） */
    private Long refId;

    /** 0未读 1已读 */
    private Integer isRead;
}
