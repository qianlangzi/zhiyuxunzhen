package com.zhiyu.service;

import com.zhiyu.vo.ImportResultVO;
import org.springframework.web.multipart.MultipartFile;

/**
 * 学生账号 Excel 批量导入服务（PRD 4.14）
 */
public interface UserImportService {

    /**
     * 批量导入学生账号
     * Excel 格式：username | realName | phone | classId
     * 密码默认 "123456"（BCrypt 加密），跳过已存在的 username
     *
     * @param file Excel 文件
     * @return 导入结果
     */
    ImportResultVO importStudents(MultipartFile file);
}
