package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.common.param.PageParam;
import com.zhiyu.common.result.PageResult;
import com.zhiyu.entity.AuditLog;
import com.zhiyu.entity.SpCaseConfig;
import com.zhiyu.entity.SysConfig;
import com.zhiyu.entity.SysUser;
import com.zhiyu.mapper.AssignmentInstanceMapper;
import com.zhiyu.mapper.AuditLogMapper;
import com.zhiyu.mapper.ChatSessionMapper;
import com.zhiyu.mapper.SpCaseConfigMapper;
import com.zhiyu.mapper.SysConfigMapper;
import com.zhiyu.mapper.SysUserMapper;
import com.zhiyu.service.AdminService;
import com.zhiyu.service.AuditLogService;
import com.zhiyu.service.dto.RejectDTO;
import com.zhiyu.service.dto.SysConfigUpdateDTO;
import com.zhiyu.vo.AuditLogVO;
import com.zhiyu.vo.CaseAuditVO;
import com.zhiyu.vo.DashboardVO;
import com.zhiyu.vo.TeacherAuditVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * 管理端服务实现（PRD 4.13 ~ 4.17）
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AdminServiceImpl implements AdminService {

    private final SysUserMapper userMapper;
    private final SpCaseConfigMapper caseConfigMapper;
    private final ChatSessionMapper chatSessionMapper;
    private final AssignmentInstanceMapper assignmentInstanceMapper;
    private final SysConfigMapper sysConfigMapper;
    private final AuditLogMapper auditLogMapper;
    private final AuditLogService auditLogService;
    private final ObjectMapper objectMapper;

    // ==================== 驾驶舱（PRD 4.13） ====================

    @Override
    public DashboardVO dashboard() {
        LocalDateTime todayStart = LocalDate.now().atStartOfDay();

        // 今日活跃学生数：role=0 且今日有登录
        Long todayActiveStudents = userMapper.selectCount(
                new LambdaQueryWrapper<SysUser>()
                        .eq(SysUser::getRole, 0)
                        .ge(SysUser::getLastLoginAt, todayStart));

        // 活跃教师数：role=1 且已认证
        Long activeTeachers = userMapper.selectCount(
                new LambdaQueryWrapper<SysUser>()
                        .eq(SysUser::getRole, 1)
                        .eq(SysUser::getAuditStatus, 2));

        // 问诊会话总数
        Long chatSessionCount = chatSessionMapper.selectCount(null);

        // 作业提交数：submit_time 不为空
        Long assignmentSubmitCount = assignmentInstanceMapper.selectCount(
                new LambdaQueryWrapper<com.zhiyu.entity.AssignmentInstance>()
                        .isNotNull(com.zhiyu.entity.AssignmentInstance::getSubmitTime));

        // 待审核病例数：is_public=true 且 admin_audit_status=1
        Long pendingCaseAuditCount = caseConfigMapper.selectCount(
                new LambdaQueryWrapper<SpCaseConfig>()
                        .eq(SpCaseConfig::getIsPublic, true)
                        .eq(SpCaseConfig::getAdminAuditStatus, 1));

        // 待审核教师数：role=1 且 audit_status IN (1,3)
        Long pendingTeacherAuditCount = userMapper.selectCount(
                new LambdaQueryWrapper<SysUser>()
                        .eq(SysUser::getRole, 1)
                        .in(SysUser::getAuditStatus, 1, 3));

        // 官方认证病例数：admin_audit_status=2
        Long officialCaseCount = caseConfigMapper.selectCount(
                new LambdaQueryWrapper<SpCaseConfig>()
                        .eq(SpCaseConfig::getAdminAuditStatus, 2));

        return DashboardVO.builder()
                .todayActiveStudents(todayActiveStudents)
                .activeTeachers(activeTeachers)
                .chatSessionCount(chatSessionCount)
                .assignmentSubmitCount(assignmentSubmitCount)
                .pendingCaseAuditCount(pendingCaseAuditCount)
                .pendingTeacherAuditCount(pendingTeacherAuditCount)
                .officialCaseCount(officialCaseCount)
                .build();
    }

    // ==================== 教师资质审核（PRD 4.14） ====================

    @Override
    public PageResult<TeacherAuditVO> teacherAuditList(PageParam param, Integer auditStatus) {
        LambdaQueryWrapper<SysUser> wrapper = new LambdaQueryWrapper<SysUser>()
                .eq(SysUser::getRole, 1);
        if (auditStatus != null) {
            wrapper.eq(SysUser::getAuditStatus, auditStatus);
        } else {
            // 默认查待审核(1)和驳回(3)
            wrapper.in(SysUser::getAuditStatus, 1, 3);
        }
        wrapper.orderByDesc(SysUser::getCreatedAt);

        Page<SysUser> page = new Page<>(param.getPageNum(), param.getPageSize());
        IPage<SysUser> result = userMapper.selectPage(page, wrapper);

        List<TeacherAuditVO> voList = result.getRecords().stream()
                .map(this::toTeacherAuditVO)
                .collect(Collectors.toList());

        return PageResult.of(result, voList);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void approveTeacher(Long userId) {
        SysUser user = userMapper.selectById(userId);
        if (user == null) {
            throw new BizException(ResultCode.NOT_FOUND, "用户不存在");
        }
        if (user.getRole() == null || user.getRole() != 1) {
            throw new BizException(ResultCode.BAD_REQUEST, "该用户不是教师");
        }

        String beforeJson = toJson(Map.of("auditStatus", user.getAuditStatus()));

        user.setAuditStatus(2);
        userMapper.updateById(user);

        String afterJson = toJson(Map.of("auditStatus", 2));

        auditLogService.record("teacher_audit_approve", "user", userId, beforeJson, afterJson);
        log.info("教师资质审核通过: userId={}", userId);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void rejectTeacher(Long userId, RejectDTO dto) {
        SysUser user = userMapper.selectById(userId);
        if (user == null) {
            throw new BizException(ResultCode.NOT_FOUND, "用户不存在");
        }
        if (user.getRole() == null || user.getRole() != 1) {
            throw new BizException(ResultCode.BAD_REQUEST, "该用户不是教师");
        }

        String beforeJson = toJson(Map.of("auditStatus", user.getAuditStatus()));

        user.setAuditStatus(3);
        userMapper.updateById(user);

        Map<String, Object> afterMap = new HashMap<>();
        afterMap.put("auditStatus", 3);
        afterMap.put("reason", dto.getReason());
        String afterJson = toJson(afterMap);

        auditLogService.record("teacher_audit_reject", "user", userId, beforeJson, afterJson);
        log.info("教师资质审核驳回: userId={}, reason={}", userId, dto.getReason());
    }

    // ==================== 病例审核（PRD 4.15） ====================

    @Override
    public PageResult<CaseAuditVO> caseAuditList(PageParam param) {
        LambdaQueryWrapper<SpCaseConfig> wrapper = new LambdaQueryWrapper<SpCaseConfig>()
                .eq(SpCaseConfig::getIsPublic, true)
                .eq(SpCaseConfig::getAdminAuditStatus, 1)
                .orderByDesc(SpCaseConfig::getCreatedAt);

        Page<SpCaseConfig> page = new Page<>(param.getPageNum(), param.getPageSize());
        IPage<SpCaseConfig> result = caseConfigMapper.selectPage(page, wrapper);

        // 批量查询创建者姓名
        Set<Long> creatorIds = result.getRecords().stream()
                .map(SpCaseConfig::getCreatorId)
                .filter(id -> id != null)
                .collect(Collectors.toSet());
        Map<Long, String> creatorNameMap = batchQueryUserNames(creatorIds);

        List<CaseAuditVO> voList = result.getRecords().stream()
                .map(c -> CaseAuditVO.builder()
                        .caseId(c.getId())
                        .title(c.getTitle())
                        .department(c.getDepartment())
                        .difficulty(c.getDifficulty())
                        .creatorId(c.getCreatorId())
                        .creatorName(c.getCreatorId() != null ? creatorNameMap.get(c.getCreatorId()) : null)
                        .createdAt(c.getCreatedAt())
                        .build())
                .collect(Collectors.toList());

        return PageResult.of(result, voList);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void approveCase(Long caseId) {
        SpCaseConfig caseConfig = caseConfigMapper.selectById(caseId);
        if (caseConfig == null) {
            throw new BizException(ResultCode.CASE_NOT_FOUND);
        }

        String beforeJson = toJson(Map.of("adminAuditStatus", caseConfig.getAdminAuditStatus()));

        caseConfig.setAdminAuditStatus(2);
        caseConfigMapper.updateById(caseConfig);

        String afterJson = toJson(Map.of("adminAuditStatus", 2));

        auditLogService.record("case_audit_approve", "sp_case_config", caseId, beforeJson, afterJson);
        log.info("病例审核通过: caseId={}", caseId);
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void rejectCase(Long caseId) {
        SpCaseConfig caseConfig = caseConfigMapper.selectById(caseId);
        if (caseConfig == null) {
            throw new BizException(ResultCode.CASE_NOT_FOUND);
        }

        String beforeJson = toJson(Map.of("adminAuditStatus", caseConfig.getAdminAuditStatus()));

        caseConfig.setAdminAuditStatus(3);
        caseConfigMapper.updateById(caseConfig);

        String afterJson = toJson(Map.of("adminAuditStatus", 3));

        auditLogService.record("case_audit_reject", "sp_case_config", caseId, beforeJson, afterJson);
        log.info("病例审核驳回: caseId={}", caseId);
    }

    // ==================== 系统配置（PRD 4.16） ====================

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void updateSysConfig(SysConfigUpdateDTO dto) {
        SysConfig existing = sysConfigMapper.selectOne(
                new LambdaQueryWrapper<SysConfig>()
                        .eq(SysConfig::getConfigKey, dto.getConfigKey()));

        if (existing != null) {
            // 更新
            String beforeJson = toJson(existing);

            existing.setConfigValue(dto.getConfigValue());
            existing.setConfigType(dto.getConfigType());
            sysConfigMapper.updateById(existing);

            String afterJson = toJson(existing);
            auditLogService.record("sys_config_update", "sys_config", existing.getId(), beforeJson, afterJson);
            log.info("系统配置更新: key={}", dto.getConfigKey());
        } else {
            // 插入
            SysConfig config = new SysConfig();
            config.setConfigKey(dto.getConfigKey());
            config.setConfigValue(dto.getConfigValue());
            config.setConfigType(dto.getConfigType());
            sysConfigMapper.insert(config);

            String afterJson = toJson(config);
            auditLogService.record("sys_config_create", "sys_config", config.getId(), null, afterJson);
            log.info("系统配置新增: key={}", dto.getConfigKey());
        }
    }

    // ==================== 审计日志查询（PRD 4.17） ====================

    @Override
    public PageResult<AuditLogVO> auditLogList(PageParam param, Long operatorId, String action,
                                                String targetType, LocalDate startDate, LocalDate endDate) {
        LambdaQueryWrapper<AuditLog> wrapper = new LambdaQueryWrapper<>();
        if (operatorId != null) {
            wrapper.eq(AuditLog::getOperatorId, operatorId);
        }
        if (StringUtils.hasText(action)) {
            wrapper.eq(AuditLog::getAction, action);
        }
        if (StringUtils.hasText(targetType)) {
            wrapper.eq(AuditLog::getTargetType, targetType);
        }
        if (startDate != null) {
            wrapper.ge(AuditLog::getCreatedAt, startDate.atStartOfDay());
        }
        if (endDate != null) {
            wrapper.le(AuditLog::getCreatedAt, endDate.atTime(23, 59, 59));
        }
        wrapper.orderByDesc(AuditLog::getCreatedAt);

        Page<AuditLog> page = new Page<>(param.getPageNum(), param.getPageSize());
        IPage<AuditLog> result = auditLogMapper.selectPage(page, wrapper);

        // 批量查询操作人姓名
        Set<Long> operatorIds = result.getRecords().stream()
                .map(AuditLog::getOperatorId)
                .filter(id -> id != null && id > 0)
                .collect(Collectors.toSet());
        Map<Long, String> operatorNameMap = batchQueryUserNames(operatorIds);

        List<AuditLogVO> voList = result.getRecords().stream()
                .map(al -> AuditLogVO.builder()
                        .id(al.getId())
                        .operatorId(al.getOperatorId())
                        .operatorName(al.getOperatorId() != null && al.getOperatorId() > 0
                                ? operatorNameMap.get(al.getOperatorId()) : null)
                        .operatorRole(al.getOperatorRole())
                        .action(al.getAction())
                        .targetType(al.getTargetType())
                        .targetId(al.getTargetId())
                        .beforeJson(al.getBeforeJson())
                        .afterJson(al.getAfterJson())
                        .ipAddress(al.getIpAddress())
                        .createdAt(al.getCreatedAt())
                        .build())
                .collect(Collectors.toList());

        return PageResult.of(result, voList);
    }

    // ==================== 工具方法 ====================

    /**
     * 教师审核 VO 转换，手机号脱敏
     */
    private TeacherAuditVO toTeacherAuditVO(SysUser user) {
        return TeacherAuditVO.builder()
                .userId(user.getId())
                .username(user.getUsername())
                .realName(user.getRealName())
                .phone(maskPhone(user.getPhone()))
                .auditStatus(user.getAuditStatus())
                .createdAt(user.getCreatedAt())
                .build();
    }

    /**
     * 手机号脱敏（PRD 10.3）：前3位 + **** + 后4位
     */
    private String maskPhone(String phone) {
        if (phone == null || phone.length() < 7) {
            return phone;
        }
        return phone.substring(0, 3) + "****" + phone.substring(phone.length() - 4);
    }

    /**
     * 批量查询用户姓名
     */
    private Map<Long, String> batchQueryUserNames(Set<Long> userIds) {
        if (userIds == null || userIds.isEmpty()) {
            return new HashMap<>();
        }
        List<SysUser> users = userMapper.selectList(
                new LambdaQueryWrapper<SysUser>()
                        .in(SysUser::getId, userIds));
        return users.stream()
                .collect(Collectors.toMap(SysUser::getId, u -> u.getRealName() != null ? u.getRealName() : u.getUsername(), (a, b) -> a));
    }

    /**
     * 对象转 JSON 字符串，失败返回 null
     */
    private String toJson(Object obj) {
        if (obj == null) {
            return null;
        }
        try {
            return objectMapper.writeValueAsString(obj);
        } catch (Exception e) {
            log.warn("JSON 序列化失败: {}", e.getMessage());
            return null;
        }
    }
}
