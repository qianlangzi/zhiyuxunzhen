package com.zhiyu.service;

import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.dto.CaseCreateDTO;
import com.zhiyu.service.dto.CaseUpdateDTO;
import com.zhiyu.vo.CasePreviewVO;
import com.zhiyu.vo.TeacherCaseListVO;

/**
 * 教师病例服务（PRD 4.1）
 */
public interface TeacherCaseService {

    /**
     * 创建病例（草稿），返回病例ID
     */
    Long create(CaseCreateDTO req);

    /**
     * 更新病例，已被作业引用时禁止修改核心诊断字段
     */
    void update(Long id, CaseUpdateDTO req);

    /**
     * 我的病例列表（分页，支持标题模糊搜索、科室筛选）
     */
    PageResult<TeacherCaseListVO> myCases(Integer pageNum, Integer pageSize, String title, String department);

    /**
     * 预览病例配置（含隐藏疾病、标准路径）
     */
    CasePreviewVO preview(Long id);

    /**
     * 发布病例到病例广场（PRD 5.1 第 4 步）
     * is_public=true + admin_audit_status=1（待管理员审核）+ status=1（已发布）
     */
    void publishToMarket(Long id);
}
