package com.zhiyu.service;

import com.zhiyu.service.dto.internal.SessionMessageAppendDTO;
import com.zhiyu.vo.AiSessionContextVO;

public interface AiSessionContextService {
    AiSessionContextVO getContext(Long sessionId, Long studentId);
    void appendMessages(Long sessionId, SessionMessageAppendDTO dto);
}
