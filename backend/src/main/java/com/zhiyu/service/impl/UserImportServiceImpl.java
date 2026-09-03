package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.zhiyu.common.constant.ResultCode;
import com.zhiyu.common.context.UserContext;
import com.zhiyu.common.exception.BizException;
import com.zhiyu.entity.SysUser;
import com.zhiyu.mapper.SysUserMapper;
import com.zhiyu.service.AuditLogService;
import com.zhiyu.service.UserImportService;
import com.zhiyu.vo.ImportResultVO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.CellType;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;

import java.security.SecureRandom;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 学生账号 Excel 批量导入服务实现（PRD 4.14）
 *
 * 安全策略：
 *   - 每个学生生成独立随机临时密码（非固定值），通过导入结果返回给管理员分发
 *   - 导入时设置 must_change_password=true，学生首次登录强制改密
 *   - 临时密码字符集排除易混淆字符（0/O, 1/I/l）
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class UserImportServiceImpl implements UserImportService {

    /** 随机密码字符集（排除 0/O/1/I/l 等易混淆字符） */
    private static final String PASSWORD_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789";
    /** 随机密码长度 */
    private static final int PASSWORD_LENGTH = 8;
    /** 单文件最大 10MB，防止超大文件耗尽内存 */
    private static final long MAX_FILE_SIZE = 10L * 1024 * 1024;
    /** 单次最多导入 5000 行，超出拒绝 */
    private static final int MAX_ROWS = 5000;
    /** 单元格字符串最大长度，超出记失败 */
    private static final int MAX_CELL_LENGTH = 100;
    /** 失败明细上限，超出仅统计不记录明细，避免响应过大 */
    private static final int MAX_FAILURES = 100;

    private final SysUserMapper userMapper;
    private final PasswordEncoder passwordEncoder;
    private final AuditLogService auditLogService;
    private final ObjectMapper objectMapper;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public ImportResultVO importStudents(MultipartFile file) {
        // 权限校验：教学秘书(2)可批量导入学生，管理员(4)可操作（PRD 3.1）
        // 拦截器已对 /api/v1/admin/users/import 精确匹配 role 2/4，此处为纵深防御
        UserContext.requireRole(2, 4);

        if (file == null || file.isEmpty()) {
            throw new BizException(ResultCode.BAD_REQUEST, "上传文件不能为空");
        }

        String fileName = file.getOriginalFilename();
        if (fileName == null || !fileName.toLowerCase().endsWith(".xlsx")) {
            throw new BizException(ResultCode.BAD_REQUEST, "仅支持 .xlsx 格式的 Excel 文件");
        }
        if (file.getSize() > MAX_FILE_SIZE) {
            throw new BizException(ResultCode.BAD_REQUEST, "文件过大，最大支持 " + (MAX_FILE_SIZE / 1024 / 1024) + "MB");
        }

        int successCount = 0;
        int failCount = 0;
        List<ImportResultVO.ImportSuccess> successes = new ArrayList<>();
        List<ImportResultVO.ImportFailure> failures = new ArrayList<>();

        try (Workbook workbook = new XSSFWorkbook(file.getInputStream())) {
            Sheet sheet = workbook.getSheetAt(0);
            if (sheet == null) {
                throw new BizException(ResultCode.BAD_REQUEST, "Excel 文件无有效工作表");
            }
            if (sheet.getLastRowNum() > MAX_ROWS) {
                throw new BizException(ResultCode.BAD_REQUEST, "数据行数超过上限 " + MAX_ROWS + " 行，请分批导入");
            }

            // 从第二行开始读取（第一行为表头）
            for (int i = 1; i <= sheet.getLastRowNum(); i++) {
                Row row = sheet.getRow(i);
                if (row == null) {
                    continue;
                }
                try {
                    String username = getCellAsString(row.getCell(0));
                    String realName = getCellAsString(row.getCell(1));
                    String phone = getCellAsString(row.getCell(2));
                    String classIdStr = getCellAsString(row.getCell(3));

                    // 校验单元格长度，防止超长字符串耗尽资源
                    if (exceedsCellLength(username) || exceedsCellLength(realName)
                            || exceedsCellLength(phone) || exceedsCellLength(classIdStr)) {
                        failCount++;
                        if (failures.size() < MAX_FAILURES) {
                            failures.add(ImportResultVO.ImportFailure.builder()
                                    .row(i + 1).username(username).reason("单元格内容超过 " + MAX_CELL_LENGTH + " 字符")
                                    .build());
                        }
                        continue;
                    }

                    // 校验必填字段
                    if (!StringUtils.hasText(username)) {
                        failCount++;
                        failures.add(ImportResultVO.ImportFailure.builder()
                                .row(i + 1).username(username).reason("用户名为空")
                                .build());
                        continue;
                    }

                    // 跳过已存在的 username
                    Long existCount = userMapper.selectCount(
                            new LambdaQueryWrapper<SysUser>()
                                    .eq(SysUser::getUsername, username));
                    if (existCount > 0) {
                        failCount++;
                        failures.add(ImportResultVO.ImportFailure.builder()
                                .row(i + 1).username(username).reason("用户名已存在")
                                .build());
                        continue;
                    }

                    // 构建用户并插入
                    String tempPassword = generateRandomPassword();
                    SysUser user = new SysUser();
                    user.setUsername(username.trim());
                    user.setRealName(StringUtils.hasText(realName) ? realName.trim() : null);
                    user.setPhone(StringUtils.hasText(phone) ? phone.trim() : null);
                    user.setRole(0); // 学生
                    user.setAuditStatus(0);
                    user.setStatus(0); // 正常
                    user.setPasswordHash(passwordEncoder.encode(tempPassword));
                    user.setMustChangePassword(true); // 强制首次登录改密
                    if (StringUtils.hasText(classIdStr)) {
                        try {
                            user.setClassId(Long.parseLong(classIdStr.trim()));
                        } catch (NumberFormatException e) {
                            failCount++;
                            failures.add(ImportResultVO.ImportFailure.builder()
                                    .row(i + 1).username(username).reason("班级ID格式错误: " + classIdStr)
                                    .build());
                            continue;
                        }
                    }
                    userMapper.insert(user);
                    successCount++;
                    successes.add(ImportResultVO.ImportSuccess.builder()
                            .row(i + 1).username(username.trim()).tempPassword(tempPassword)
                            .build());
                } catch (Exception e) {
                    failCount++;
                    String username = getCellAsString(row.getCell(0));
                    // 不向客户端返回底层 e.getMessage()，避免泄露内部实现细节
                    failures.add(ImportResultVO.ImportFailure.builder()
                            .row(i + 1).username(username).reason("导入异常，请检查数据格式")
                            .build());
                    log.warn("学生导入第{}行异常: {}", i + 1, e.getMessage(), e);
                }
            }
        } catch (BizException e) {
            throw e;
        } catch (Exception e) {
            log.error("Excel 解析失败", e);
            throw new BizException(ResultCode.FILE_UPLOAD_ERROR, "Excel 解析失败，请检查文件格式是否正确");
        }

        // 记录审计日志
        // H1 修复：afterMap.toString() 生成 {fileName=x} 不是合法 JSON，写入 MySQL JSON 列会失败。
        // P1-5 后审计异常向外传播，会导致整个导入事务回滚。改用 ObjectMapper 序列化。
        Map<String, Object> afterMap = new HashMap<>();
        afterMap.put("fileName", fileName);
        afterMap.put("successCount", successCount);
        afterMap.put("failCount", failCount);
        String afterJson;
        try {
            afterJson = objectMapper.writeValueAsString(afterMap);
        } catch (Exception e) {
            log.error("审计 JSON 序列化失败，降级为空 JSON", e);
            afterJson = "{}";
        }
        auditLogService.record("student_import", "user", null, null, afterJson);

        // 失败明细上限：超出仅保留前 MAX_FAILURES 条，避免响应过大
        if (failures.size() > MAX_FAILURES) {
            log.warn("导入失败明细 {} 条超过上限 {}，仅返回前 {} 条", failures.size(), MAX_FAILURES, MAX_FAILURES);
            failures = new ArrayList<>(failures.subList(0, MAX_FAILURES));
        }

        log.info("学生账号批量导入完成: 文件={}, 成功={}, 失败={}", fileName, successCount, failCount);

        return ImportResultVO.builder()
                .successCount(successCount)
                .failCount(failCount)
                .successes(successes)
                .failures(failures)
                .build();
    }

    /**
     * 生成随机临时密码（SecureRandom，排除易混淆字符）
     */
    private String generateRandomPassword() {
        SecureRandom random = new SecureRandom();
        StringBuilder sb = new StringBuilder(PASSWORD_LENGTH);
        for (int i = 0; i < PASSWORD_LENGTH; i++) {
            sb.append(PASSWORD_CHARS.charAt(random.nextInt(PASSWORD_CHARS.length())));
        }
        return sb.toString();
    }

    /** 判断字符串是否超过单元格最大长度 */
    private boolean exceedsCellLength(String value) {
        return value != null && value.length() > MAX_CELL_LENGTH;
    }

    /**
     * 读取单元格内容为字符串
     */
    private String getCellAsString(Cell cell) {
        if (cell == null) {
            return null;
        }
        if (cell.getCellType() == CellType.STRING) {
            return cell.getStringCellValue();
        }
        if (cell.getCellType() == CellType.NUMERIC) {
            // 避免数字被转为科学计数法
            double num = cell.getNumericCellValue();
            if (num == Math.floor(num)) {
                return String.valueOf((long) num);
            }
            return String.valueOf(num);
        }
        if (cell.getCellType() == CellType.BOOLEAN) {
            return String.valueOf(cell.getBooleanCellValue());
        }
        if (cell.getCellType() == CellType.FORMULA) {
            try {
                return cell.getStringCellValue();
            } catch (Exception e) {
                try {
                    return String.valueOf(cell.getNumericCellValue());
                } catch (Exception ignored) {
                    return null;
                }
            }
        }
        return null;
    }
}
