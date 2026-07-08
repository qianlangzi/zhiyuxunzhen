package com.zhiyu.service;

import com.zhiyu.service.dto.internal.MistakesSyncDTO;
import com.zhiyu.service.dto.internal.ModelEventLogDTO;
import com.zhiyu.service.dto.internal.ReviewCallbackDTO;
import com.zhiyu.service.dto.internal.SessionArchiveDTO;
import com.zhiyu.service.dto.internal.WeaknessSyncDTO;

/**
 * 内部回调服务（PRD 9.4）
 * 接收 FastAPI 中台的异步回调，更新业务数据
 */
public interface InternalCallbackService {

    /**
     * 归档问诊会话（更新 ChatSession 状态为已完成，存评分/报告/思维树）
     */
    void archiveSession(SessionArchiveDTO dto);

    /**
     * 写入 AI 批阅结果（创建 MedicalRecordReview，更新 AssignmentInstance 状态为待复核）
     */
    void reviewCallback(ReviewCallbackDTO dto);

    /**
     * 同步错题本（批量插入 StudentMistakes）
     */
    void syncMistakes(MistakesSyncDTO dto);

    /**
     * 同步薄弱知识点（upsert StudentWeakness）
     */
    void syncWeakness(WeaknessSyncDTO dto);

    /**
     * 记录模型异常和降级事件
     */
    void logModelEvent(ModelEventLogDTO dto);
}
