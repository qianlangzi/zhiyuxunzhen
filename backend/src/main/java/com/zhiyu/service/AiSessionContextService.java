package com.zhiyu.service;

import com.zhiyu.service.dto.internal.SessionMessageAppendDTO;
import com.zhiyu.vo.AiSessionContextVO;
import com.zhiyu.vo.AiReportContextVO;

public interface AiSessionContextService {
    AiSessionContextVO getContext(Long sessionId, Long studentId);
    void appendMessages(Long sessionId, SessionMessageAppendDTO dto);
    AiReportContextVO getReportContext(Long sessionId);
}
