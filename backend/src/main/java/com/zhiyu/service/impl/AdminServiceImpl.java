package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
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
import org.springframework.security.crypto.password.PasswordEncoder;
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
    private final PasswordEncoder passwordEncoder;

    /** 默认演示密码，与 ProdSecurityInitializer.DEMO_PASSWORD 保持一致 */
    private static final String DEMO_PASSWORD = "123456";

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

        // P1：审核通过时递增 credential_version，撤销携带旧 auditStatus 的 access token。
        // PermissionInterceptor 依赖 auditStatus=2 才允许教师写操作，旧 token 中的
        // auditStatus=1（待审核）会让教师无法写操作；但若攻击者在审核通过前拿到 token，
        // 审核通过后旧 token 仍带 auditStatus=1，需递增版本强制重新登录拿 auditStatus=2 的新 token。
        //
        // P1-1 修复：CAS 条件增加 .eq("audit_status", 1)，仅待审核状态才可审核通过。
        // 防止迟到 approve 覆盖较新的 reject（管理员先驳回再批准，但迟到的批准请求
        // 在驳回之后执行，把已驳回的账号又变成通过）。
        //
        // H3 修复：CAS 增加 .eq("credential_version", user.getCredentialVersion()) 消除 ABA。
        // 旧 CAS 仅匹配 audit_status=1 → ABA：待审(1)→驳回(3,cv+1)→教师重提交(1)→旧 approve 恢复，
        // 旧请求批准了未经审核的新材料。加入 cv 条件后，驳回递增了 cv，旧 approve 持有的旧 cv 不匹配。
        int rows = userMapper.update(null,
                new com.baomidou.mybatisplus.core.conditions.update.UpdateWrapper<SysUser>()
                        .eq("id", userId)
                        .eq("audit_status", 1)
                        .eq("credential_version", user.getCredentialVersion())
                        .eq("is_deleted", 0)
                        .set("audit_status", 2)
                        .setSql("credential_version = credential_version + 1"));
        if (rows == 0) {
            throw new BizException(ResultCode.BAD_REQUEST, "教师不在待审核状态，无法审核通过");
        }

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

        // P1：审核驳回时递增 credential_version，撤销旧 token，强制教师重新登录拿 auditStatus=3 的新 token。
        // 驳回后旧 token 的 auditStatus=1（待审核）仍能尝试写操作，递增版本后旧 token 被立即拒绝。
        //
        // P1-1 修复：CAS 条件增加 .eq("audit_status", 1)，仅待审核状态才可驳回。
        // 防止迟到 reject 覆盖较新的 approve（管理员先批准再驳回，但迟到的驳回请求
        // 在批准之后执行，把已通过的账号又变成驳回）。
        //
        // H3 修复：CAS 增加 .eq("credential_version", user.getCredentialVersion()) 消除 ABA。
        int rows = userMapper.update(null,
                new com.baomidou.mybatisplus.core.conditions.update.UpdateWrapper<SysUser>()
                        .eq("id", userId)
                        .eq("audit_status", 1)
                        .eq("credential_version", user.getCredentialVersion())
                        .eq("is_deleted", 0)
                        .set("audit_status", 3)
                        .setSql("credential_version = credential_version + 1"));
        if (rows == 0) {
            throw new BizException(ResultCode.BAD_REQUEST, "教师不在待审核状态，无法驳回");
        }

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

    // ==================== 用户管理（PRD 4.14 / 4.17） ====================

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void freezeUser(Long userId) {
        SysUser user = userMapper.selectById(userId);
        if (user == null) {
            throw new BizException(ResultCode.NOT_FOUND, "用户不存在");
        }
        if (user.getRole() != null && (user.getRole() == 4 || user.getRole() == 5)) {
            throw new BizException(ResultCode.BAD_REQUEST, "不允许冻结管理员/运维账号");
        }
        String beforeJson = toJson(Map.of("status", user.getStatus()));
        // P1：冻结时同步递增 credential_version，撤销该用户所有已签发的 access/refresh token。
        // MustChangePasswordInterceptor 的版本校验会立即拒绝旧 token，防止冻结后旧 token
        // 在 24h access 有效期内继续操作。使用 UpdateWrapper + setSql 原子递增，避免
        // LambdaUpdateWrapper 的 lambda cache 在隔离测试中未预热导致 NPE。
        //
        // 复审 F5 修复：补 .eq("credential_version", ...) 与 unfreezeUser/approve/reject 对称，
        // 封死 freeze→unfreeze→迟到 freeze 的 ABA：
        //   t0 A 读库 (status=0, cv=v) → t1 B 冻结成功 (cv v→v+1) → t2 解冻 (cv 不变)
        //   → t3 迟到的 A 执行：仅有 .eq("status",0) 仍匹配（状态已回到 0）→ 错误冻结并杀新 token。
        //   加 cv CAS 后 A 持有的 v 与 DB 的 v+1 不匹配 → rows=0 → 拒绝。
        int rows = userMapper.update(null,
                new com.baomidou.mybatisplus.core.conditions.update.UpdateWrapper<SysUser>()
                        .eq("id", userId)
                        .eq("status", 0)
                        .eq("credential_version", user.getCredentialVersion())
                        .eq("is_deleted", 0)
                        .set("status", 1)
                        .setSql("credential_version = credential_version + 1"));
        if (rows == 0) {
            throw new BizException(ResultCode.BAD_REQUEST, "用户不存在、已删除、已被冻结或账号状态已变更");
        }
        String afterJson = toJson(Map.of("status", 1));
        auditLogService.record("user_freeze", "user", userId, beforeJson, afterJson);
        log.info("账号冻结: userId={}, operator={}", userId, UserContext.requireUserId());
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void unfreezeUser(Long userId) {
        SysUser user = userMapper.selectById(userId);
        if (user == null) {
            throw new BizException(ResultCode.NOT_FOUND, "用户不存在");
        }
        // H4 修复：禁止解冻仍使用默认弱密码的账号。
        // ProdSecurityInitializer 会冻结密码仍为 123456 的演示账号，但解冻时不检查密码，
        // 其他管理员一旦解冻 admin01，公开弱密码立即重新可用。
        if (passwordEncoder.matches(DEMO_PASSWORD, user.getPasswordHash())) {
            throw new BizException(ResultCode.BAD_REQUEST,
                    "该账号仍在使用默认弱密码，请先重置密码后再解冻");
        }
        String beforeJson = toJson(Map.of("status", user.getStatus()));
        // 解冻不递增 credential_version：冻结时已撤销旧 token，用户解冻后需重新登录获取新 token。
        // 若解冻也递增版本，会导致用户刚解冻就被迫再次重登（体验差且无安全收益）。
        //
        // P0-4 修复：使用窄字段 UpdateWrapper 只更新 status，不使用 updateById(user)。
        // updateById 会写入完整实体快照，并发场景下可能把另一个事务已递增的 credential_version
        // 或修改的 role/passwordHash 写回旧值，导致撤销被回滚。窄字段 UPDATE 只动 status 列。
        //
        // P1-1 修复：CAS 条件增加 .eq("status", 1)，仅当前为冻结状态才解冻。
        // 防止迟到 unfreeze 覆盖较新的 freeze（管理员先冻结再解冻，但迟到的解冻请求
        // 在冻结之后执行，把已冻结的账号又解冻了）。
        //
        // H3 修复：CAS 增加 .eq("credential_version", user.getCredentialVersion()) 消除 ABA。
        // 冻结递增 cv → 解冻不递增 → 再次冻结递增 cv。旧解冻持有的旧 cv 不匹配，防止
        // 1→0→1 后旧解冻请求撤销最新冻结。
        int rows = userMapper.update(null,
                new com.baomidou.mybatisplus.core.conditions.update.UpdateWrapper<SysUser>()
                        .eq("id", userId)
                        .eq("status", 1)
                        .eq("credential_version", user.getCredentialVersion())
                        .eq("is_deleted", 0)
                        .set("status", 0));
        if (rows == 0) {
            throw new BizException(ResultCode.BAD_REQUEST, "账号未处于冻结状态，无需解冻");
        }
        String afterJson = toJson(Map.of("status", 0));
        auditLogService.record("user_unfreeze", "user", userId, beforeJson, afterJson);
        log.info("账号解冻: userId={}, operator={}", userId, UserContext.requireUserId());
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public void changeUserRole(Long userId, Integer newRole) {
        if (newRole == null || newRole < 0 || newRole > 3) {
            throw new BizException(ResultCode.BAD_REQUEST, "目标角色非法，仅支持 0-3");
        }
        SysUser user = userMapper.selectById(userId);
        if (user == null) {
            throw new BizException(ResultCode.NOT_FOUND, "用户不存在");
        }
        if (user.getRole() != null && (user.getRole() == 4 || user.getRole() == 5)) {
            throw new BizException(ResultCode.BAD_REQUEST, "不允许修改管理员/运维角色");
        }
        if (newRole.equals(user.getRole())) {
            return; // 无变化
        }
        String beforeJson = toJson(Map.of("role", user.getRole()));
        // 角色变更后重置审核状态：教师(1)需重新认证，其他角色置为已通过(2)
        Integer newAuditStatus = (newRole == 1) ? 0 : 2;
        // P1：角色变更时同步递增 credential_version，撤销携带旧角色的 access token。
        // PermissionInterceptor 信任 JWT 中的 role claim，若不递增版本，降权/升权后的
        // 旧 token 最长 24h 仍以旧角色访问端点（如学生 token 升级为教师后可调教师接口，
        // 或教师 token 降级为学生后仍可调教师接口）。递增版本后旧 token 被立即拒绝，
        // 用户必须重新登录获取携带新角色的 token。
        int rows = userMapper.update(null,
                new com.baomidou.mybatisplus.core.conditions.update.UpdateWrapper<SysUser>()
                        .eq("id", userId)
                        .set("role", newRole)
                        .set("audit_status", newAuditStatus)
                        .setSql("credential_version = credential_version + 1"));
        if (rows == 0) {
            throw new BizException(ResultCode.NOT_FOUND, "用户不存在或已被删除");
        }
        Map<String, Object> after = new HashMap<>();
        after.put("role", newRole);
        after.put("auditStatus", newAuditStatus);
        auditLogService.record("user_role_change", "user", userId, beforeJson, toJson(after));
        log.info("用户角色变更: userId={} {}->{} operator={}",
                userId, beforeJson, newRole, UserContext.requireUserId());
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
                .certificateNo(user.getTeacherCertificateNo())
                .department(user.getDepartment())
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
