package com.zhiyu.service;

import com.zhiyu.vo.StudentWeaknessVO;

import java.util.List;

/**
 * 学生薄弱知识点服务（PRD 8.9）
 */
public interface StudentWeaknessService {

    /**
     * 当前学生的薄弱知识点列表，按 weaknessScore 升序（越低越薄弱）
     */
    List<StudentWeaknessVO> myWeaknesses();
}
