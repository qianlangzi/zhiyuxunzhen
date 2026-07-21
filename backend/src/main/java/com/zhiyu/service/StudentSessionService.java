package com.zhiyu.service;

import com.zhiyu.service.dto.SessionStartDTO;
import com.zhiyu.vo.SessionStartVO;
import com.zhiyu.vo.StudentSessionDetailVO;

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
}
