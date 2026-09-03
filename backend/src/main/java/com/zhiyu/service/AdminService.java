package com.zhiyu.service;

import com.zhiyu.common.param.PageParam;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.dto.RejectDTO;
import com.zhiyu.service.dto.SysConfigUpdateDTO;
import com.zhiyu.service.dto.CreateAuditorDTO;
import com.zhiyu.vo.AdminUserStatsVO;
import com.zhiyu.vo.AdminUserVO;
import com.zhiyu.vo.AuditLogVO;
import com.zhiyu.vo.CaseAuditDetailVO;
import com.zhiyu.vo.CaseAuditVO;
import com.zhiyu.vo.DashboardVO;
import com.zhiyu.vo.QuestionAuditVO;
import com.zhiyu.vo.SysConfigVO;
import com.zhiyu.vo.TeacherAuditDetailVO;
import com.zhiyu.vo.TeacherAuditVO;
import com.zhiyu.vo.TeacherQuestionVO;
import com.zhiyu.vo.TextbookAdminVO;

import java.util.List;
import java.util.Map;

import java.time.LocalDate;

/**
 * 管理端服务（PRD 4.13 ~ 4.17）
 */
public interface AdminService {

    /**
     * 全局驾驶舱聚合指标（PRD 4.13）
     */
    DashboardVO dashboard();

    /**
     * 教师资质审核列表（PRD 4.14）
     *
     * @param param       分页参数
     * @param auditStatus 审核状态筛选，null 则查待审核(1)和驳回(3)
     */
    PageResult<TeacherAuditVO> teacherAuditList(PageParam param, Integer auditStatus);

    /**
     * 教师资质审核详情（PRD 4.14 扩展：查看详情，含完整资质信息）
     */
    TeacherAuditDetailVO teacherAuditDetail(Long userId);

    /**
     * 审核通过教师资质（PRD 4.14）
     */
    void approveTeacher(Long userId);

    /**
     * 驳回教师资质（PRD 4.14）
     */
    void rejectTeacher(Long userId, RejectDTO dto);

    /**
     * 病例审核列表（PRD 4.15）
     */
    PageResult<CaseAuditVO> caseAuditList(PageParam param, Integer auditStatus);

    /**
     * 病例审核详情（PRD 4.15 扩展：查看详情，含完整病例内容）
     */
    CaseAuditDetailVO caseAuditDetail(Long caseId);

    /**
     * 病例审核通过（PRD 4.15）
     */
    void approveCase(Long caseId);

    /**
     * 病例审核驳回（PRD 4.15）
     */
    void rejectCase(Long caseId);

    /**
     * 基础题审核列表（PRD 4.15 扩展：题库审核，adminAuditStatus=1 待审核）
     */
    PageResult<QuestionAuditVO> questionAuditList(PageParam param, Integer auditStatus);

    /**
     * 基础题审核详情（含题干/选项/答案/解析，供审核人查看）
     */
    TeacherQuestionVO questionAuditDetail(Long questionId);

    /**
     * 基础题审核通过（1 → 2，学生可见）
     */
    void approveQuestion(Long questionId);

    /**
     * 基础题审核驳回（1 → 3，附复核意见，退还给教师）
     */
    void rejectQuestion(Long questionId, RejectDTO dto);

    /**
     * 教材列表（管理端全量，含入库状态/上传教师）
     */
    PageResult<TextbookAdminVO> textbookList(PageParam param);

    /**
     * 触发教材向量化入库（调用 AI /knowledge/ingest，异步完成回调更新状态）
     */
    Map<String, Object> triggerTextbookIngest(Long textbookId);

    /**
     * 查询教材最近一次入库任务详情（AI 任务状态/尝试次数/错误信息；AI 不可达时返回本地持久化信息）
     */
    Map<String, Object> textbookIngestTask(Long textbookId);

    /**
     * 教材上架/下架切换（status 0/1）
     */
    void toggleTextbook(Long textbookId);

    /**
     * 更新系统配置，upsert 逻辑（PRD 4.16）
     */
    void updateSysConfig(SysConfigUpdateDTO dto);

    /**
     * 查询全部系统配置（PRD 4.16）
     */
    List<SysConfigVO> listSysConfig();

    /**
     * 审计日志查询（PRD 4.17）
     *
     * @param param      分页参数
     * @param operatorId 操作人ID筛选
     * @param action     动作筛选
     * @param targetType 对象类型筛选
     * @param startDate  开始日期
     * @param endDate    结束日期
     */
    PageResult<AuditLogVO> auditLogList(PageParam param, Long operatorId, String action,
                                        String targetType, LocalDate startDate, LocalDate endDate);

    /**
     * 冻结账号（PRD 4.14 / 4.17）
     * status: 0 → 1，写审计日志
     */
    void freezeUser(Long userId);

    /**
     * 解冻账号（PRD 4.14 / 4.17）
     * status: 1 → 0，写审计日志
     */
    void unfreezeUser(Long userId);

    /**
     * 修改用户角色（PRD 4.14 / 4.17）
     * 仅允许在学生(0) ↔ 教师(1) ↔ 教学秘书(2) ↔ 教研室主任(3) 之间切换
     * 管理员(4) / 运维(5) 角色变更需走更高级别审批，本接口不处理
     */
    void changeUserRole(Long userId, Integer newRole);

    /**
     * 创建普通审核员账号（role=6，仅超级管理员可开通）
     * 审核员仅可访问审核中心，无法查看模型管理/系统配置/审计日志等运维类模块。
     */
    void createAuditor(CreateAuditorDTO dto);

    /**
     * 用户列表分页查询（人数管理 PRD 4.14）
     * 补齐此前"只有写操作、没有列表查询"的链路断点
     *
     * @param param   分页参数
     * @param role    角色筛选，null = 全部
     * @param status  状态筛选 0正常 1冻结，null = 全部
     * @param keyword 关键词（用户名/姓名/学校/手机号模糊匹配），null = 不筛选
     */
    PageResult<AdminUserVO> listUsers(PageParam param, Integer role, Integer status, String keyword);

    /**
     * 人数总览：各角色人数 / 冻结数 / 待审教师 / 新增趋势
     */
    AdminUserStatsVO userStats();

    /**
     * 重置用户密码为随机强密码，并强制其下次登录修改
     * 同时递增 credentialVersion 撤销该用户已签发的全部旧凭证
     *
     * <p>刻意不使用 DEMO_PASSWORD(123456) 作为重置结果：unfreezeUser 会拒绝解冻
     * 仍处于默认弱密码的账号，若重置回 123456，被冻结账号将陷入
     * "重置→仍是弱密码→无法解冻→登不进去改密码" 的死循环。
     *
     * @return 新密码明文（仅此次返回，不落库明文）
     */
    String resetPassword(Long userId);

    /**
     * 批量冻结/解冻账号
     *
     * @param userIds 用户 ID 列表
     * @param freeze  true=冻结 false=解冻
     * @return 实际变更条数
     */
    int batchFreeze(List<Long> userIds, boolean freeze);
}
