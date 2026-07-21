package com.zhiyu.service;

import com.zhiyu.service.dto.AssignmentCreateDTO;
import com.zhiyu.vo.AssignmentProgressVO;
import com.zhiyu.vo.TeacherAssignmentListVO;
import com.zhiyu.vo.TeachingClassVO;
import java.util.List;

/**
 * 教师作业服务（PRD 4.3）
 */
public interface TeacherAssignmentService {

    /**
     * 创建作业，并为班级每个学生生成作业实例，返回作业ID
     */
    Long create(AssignmentCreateDTO req);

    /**
     * 作业进度统计及学生明细
     */
    AssignmentProgressVO progress(Long assignmentId);

    List<TeacherAssignmentListVO> list();

    List<TeachingClassVO> classes();
}
