package com.zhiyu.service;

import com.zhiyu.service.dto.SessionStartDTO;
import com.zhiyu.vo.SessionStartVO;
import com.zhiyu.vo.StudentSessionDetailVO;

import java.util.Map;

/**
 * 学生问诊会话服务（PRD 5.2 第 1 步）
 */
public interface StudentSessionService {

    /**
     * 启动问诊会话：校验病例/实例归属 → 创建 ChatSession → 关联实例（如有）→ 返回 sessionId
     */
    SessionStartVO start(SessionStartDTO req);

    /** 查询当前学生自己的会话和已持久化消息。 */
    StudentSessionDetailVO detail(Long sessionId);

    void finish(Long sessionId);

    /**
     * 问诊聊天：校验会话归属与状态 → 转发至 AI 中台同步接口 → 返回 SP 回复等聚合数据
     */
    Map<String, Object> chat(Long sessionId, String message);
}
