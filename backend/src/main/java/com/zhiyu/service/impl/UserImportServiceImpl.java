package com.zhiyu.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
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

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 学生账号 Excel 批量导入服务实现（PRD 4.14）
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class UserImportServiceImpl implements UserImportService {

    private static final String DEFAULT_PASSWORD = "123456";

    private final SysUserMapper userMapper;
    private final PasswordEncoder passwordEncoder;
    private final AuditLogService auditLogService;

    @Override
    @Transactional(rollbackFor = Exception.class)
    public ImportResultVO importStudents(MultipartFile file) {
        // 权限校验：该接口路径不在 /admin/ 前缀下，需手动校验管理员权限
        UserContext.requireAdmin();

        if (file == null || file.isEmpty()) {
            throw new BizException(ResultCode.BAD_REQUEST, "上传文件不能为空");
        }

        String fileName = file.getOriginalFilename();
        if (fileName == null || !fileName.toLowerCase().endsWith(".xlsx")) {
            throw new BizException(ResultCode.BAD_REQUEST, "仅支持 .xlsx 格式的 Excel 文件");
        }

        int successCount = 0;
        int failCount = 0;
        List<ImportResultVO.ImportFailure> failures = new ArrayList<>();

        try (Workbook workbook = new XSSFWorkbook(file.getInputStream())) {
            Sheet sheet = workbook.getSheetAt(0);
            if (sheet == null) {
                throw new BizException(ResultCode.BAD_REQUEST, "Excel 文件无有效工作表");
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
                    SysUser user = new SysUser();
                    user.setUsername(username.trim());
                    user.setRealName(StringUtils.hasText(realName) ? realName.trim() : null);
                    user.setPhone(StringUtils.hasText(phone) ? phone.trim() : null);
                    user.setRole(0); // 学生
                    user.setAuditStatus(0);
                    user.setStatus(0); // 正常
                    user.setPasswordHash(passwordEncoder.encode(DEFAULT_PASSWORD));
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
                } catch (Exception e) {
                    failCount++;
                    String username = getCellAsString(row.getCell(0));
                    failures.add(ImportResultVO.ImportFailure.builder()
                            .row(i + 1).username(username).reason("导入异常: " + e.getMessage())
                            .build());
                    log.warn("学生导入第{}行异常: {}", i + 1, e.getMessage());
                }
            }
        } catch (BizException e) {
            throw e;
        } catch (Exception e) {
            log.error("Excel 解析失败", e);
            throw new BizException(ResultCode.FILE_UPLOAD_ERROR, "Excel 解析失败: " + e.getMessage());
        }

        // 记录审计日志
        Map<String, Object> afterMap = new HashMap<>();
        afterMap.put("fileName", fileName);
        afterMap.put("successCount", successCount);
        afterMap.put("failCount", failCount);
        auditLogService.record("student_import", "user", null, null, afterMap.toString());

        log.info("学生账号批量导入完成: 文件={}, 成功={}, 失败={}", fileName, successCount, failCount);

        return ImportResultVO.builder()
                .successCount(successCount)
                .failCount(failCount)
                .failures(failures)
                .build();
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
