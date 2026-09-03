package com.zhiyu.service;

import com.zhiyu.service.dto.TeachingClassCreateDTO;
import com.zhiyu.service.dto.TeachingClassJoinDTO;
import com.zhiyu.vo.MyClassVO;
import com.zhiyu.vo.StudentClassDetailVO;
import com.zhiyu.vo.TeachingClassMemberVO;
import com.zhiyu.vo.TeachingClassVO;

import java.util.List;

/**
 * 班级管理（教师自建班级 + 学生邀请加入）
 */
public interface TeachingClassService {

    /** 当前教师的班级（自建优先 + 管理员授权），含邀请码 */
    List<TeachingClassVO> myClasses();

    /** 班级详情（含邀请码） */
    TeachingClassVO detail(Long classId);

    /** 教师新建班级，并自动建立教师授权 */
    TeachingClassVO create(TeachingClassCreateDTO req);

    /** 重命名（仅创建教师） */
    TeachingClassVO rename(Long classId, TeachingClassCreateDTO req);

    /** 解散班级（仅创建教师）；解散后清空学生归属 */
    void dissolve(Long classId);

    /** 班级成员（学生）列表 */
    List<TeachingClassMemberVO> members(Long classId);

    /** 批量保存班级排序（按传入 id 顺序写入 sort_order） */
    void sortOrder(List<Long> classIds);

    /** 学生通过邀请码加入班级 */
    TeachingClassVO joinByCode(TeachingClassJoinDTO req);

    /** 学生已加入的班级列表（多对多，学习通式「我的课程」） */
    List<MyClassVO> myStudentClasses();

    /** 学生端班级基础信息（仅该班成员可见） */
    StudentClassDetailVO studentClassBase(Long classId);
}