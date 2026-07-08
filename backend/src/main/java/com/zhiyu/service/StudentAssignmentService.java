package com.zhiyu.service;

import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.dto.SubmitRecordDTO;
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
     * 提交大病历：格式盾牌校验，通过置为AI批阅中，失败置为格式打回
     */
    SubmitRecordResultVO submitRecord(Long instanceId, SubmitRecordDTO req);
}
