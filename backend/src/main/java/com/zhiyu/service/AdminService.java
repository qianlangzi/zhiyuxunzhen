package com.zhiyu.service;

import com.zhiyu.common.param.PageParam;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.dto.RejectDTO;
import com.zhiyu.service.dto.SysConfigUpdateDTO;
import com.zhiyu.vo.AuditLogVO;
import com.zhiyu.vo.CaseAuditVO;
import com.zhiyu.vo.DashboardVO;
import com.zhiyu.vo.TeacherAuditVO;

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
    PageResult<CaseAuditVO> caseAuditList(PageParam param);

    /**
     * 病例审核通过（PRD 4.15）
     */
    void approveCase(Long caseId);

    /**
     * 病例审核驳回（PRD 4.15）
     */
    void rejectCase(Long caseId);

    /**
     * 更新系统配置，upsert 逻辑（PRD 4.16）
     */
    void updateSysConfig(SysConfigUpdateDTO dto);

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
}
