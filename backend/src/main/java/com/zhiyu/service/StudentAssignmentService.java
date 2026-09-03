package com.zhiyu.service;

import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.dto.PracticeSubmitDTO;
import com.zhiyu.service.dto.SubmitRecordDTO;
import com.zhiyu.vo.PracticeSubmitResultVO;
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
     * 作业实例详情（用于查看作业信息 + 任务项清单 + 提交）
     */
    StudentAssignmentDetailVO detail(Long instanceId);

    /**
     * 提交大病历（病例任务项）：格式盾牌校验，通过置为AI批阅中，失败置为格式打回
     *
     * @param instanceId     作业实例 ID
     * @param itemProgressId 组合包任务项进度 ID（存量作业传 null）
     */
    SubmitRecordResultVO submitRecord(Long instanceId, Long itemProgressId, SubmitRecordDTO req);

    /**
     * 提交练习任务项答案：客观题自动判分，返回得分
     *
     * @param instanceId     作业实例 ID
     * @param itemProgressId 组合包任务项进度 ID（必填）
     */
    PracticeSubmitResultVO submitPractice(Long instanceId, Long itemProgressId, PracticeSubmitDTO req);

    /**
     * 标记阅读任务项完成
     *
     * @param instanceId     作业实例 ID
     * @param itemProgressId 组合包任务项进度 ID（必填）
     */
    PracticeSubmitResultVO completeReading(Long instanceId, Long itemProgressId);
}
