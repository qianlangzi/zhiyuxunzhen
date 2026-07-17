package com.zhiyu.service;

import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.dto.DailyCaseAnswerDTO;
import com.zhiyu.service.dto.DailyCaseScheduleDTO;
import com.zhiyu.vo.DailyCaseVO;

/**
 * 每日一例服务（PRD 4.10 / 4.16 / 8.10）
 */
public interface DailyCaseService {

    /**
     * 管理员排期每日一例（PRD 4.16）
     */
    Long schedule(DailyCaseScheduleDTO dto);

    /**
     * 管理员排期列表（分页）
     */
    PageResult<DailyCaseVO> scheduleList(Integer pageNum, Integer pageSize);

    /**
     * 学生获取今日每日一例（PRD 4.10.2）
     * 返回今天已发布(status=2)的排期，无则返回 null
     */
    DailyCaseVO today();

    /**
     * 学生提交每日一例答案（PRD 4.10.2）
     * 调用 AI 中台评估，返回评估结果 JSON
     */
    String submitAnswer(DailyCaseAnswerDTO dto);
}
