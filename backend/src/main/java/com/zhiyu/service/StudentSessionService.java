package com.zhiyu.service;

import com.zhiyu.entity.ChatSession;
import com.zhiyu.service.dto.SessionStartDTO;
import com.zhiyu.vo.SessionStartVO;
import com.zhiyu.vo.StudentSessionDetailVO;

import java.util.List;
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

    /** 重试异常会话的 AI 评估与归档。 */
    void retryArchive(Long sessionId);

    /**
     * 问诊聊天：校验会话归属与状态 → 转发至 AI 中台同步接口 → 返回 SP 回复等聚合数据
     */
    Map<String, Object> chat(Long sessionId, String message);

    /**
     * 校验会话归属当前学生并返回实体（流式转发场景复用）
     *
     * @throws com.zhiyu.common.exception.BizException NOT_FOUND / FORBIDDEN
     */
    ChatSession requireSessionForStudent(Long sessionId, Long studentId);

    /**
     * 影像 AI 读图分析（多模态，PRD 9.2）：校验会话归属 → 转发 AI Vision。
     * AI 未配置或调用失败时返回降级反馈，不抛异常。
     */
    Map<String, Object> analyzeImage(Long sessionId, String imageUrl,
                                     List<Double> imageBbox, String studentNote, String mobileToken);

    /**
     * 导师按需小结（2026-09-03）：学生主动请求时生成当前会话的思维树 + 苏格拉底提示。
     * 训练态不在对话流里实时推送（防剧透），改为按需拉取。校验会话归属与进行中状态。
     */
    Map<String, Object> mentor(Long sessionId);
}
