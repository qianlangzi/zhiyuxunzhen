package com.zhiyu.service;

import com.zhiyu.service.dto.SessionStartDTO;
import com.zhiyu.vo.SessionStartVO;

/**
 * 学生问诊会话服务（PRD 5.2 第 1 步）
 */
public interface StudentSessionService {

    /**
     * 启动问诊会话：校验病例/实例归属 → 创建 ChatSession → 关联实例（如有）→ 返回 sessionId
     */
    SessionStartVO start(SessionStartDTO req);
}
