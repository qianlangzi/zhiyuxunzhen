package com.zhiyu.service;

import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.dto.SubmitRecordDTO;
import com.zhiyu.vo.StudentAssignmentDetailVO;
import com.zhiyu.vo.StudentAssignmentVO;
import com.zhiyu.vo.SubmitRecordResultVO;

/**
 * 学生作业服务（PRD 4.4 / 9.1）
 */
public interface StudentAssignmentService {

    /**
     * 我的作业列表（分页）
     */
    PageResult<StudentAssignmentVO> myAssignments(Integer pageNum, Integer pageSize);

    /**
     * 待办作业列表（分页）：仅返回未完成（0未开始 / 1问诊中 / 2格式打回）的作业
     */
    PageResult<StudentAssignmentVO> todoAssignments(Integer pageNum, Integer pageSize);

    /**
     * 作业实例详情（用于查看作业信息 + 提交大病历）
     */
    StudentAssignmentDetailVO detail(Long instanceId);

    /**
     * 提交大病历：格式盾牌校验，通过置为AI批阅中，失败置为格式打回
     */
    SubmitRecordResultVO submitRecord(Long instanceId, SubmitRecordDTO req);
}
