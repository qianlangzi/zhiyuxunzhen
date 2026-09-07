package com.zhiyu.service;

import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.dto.DailyCaseScheduleDTO;
import com.zhiyu.vo.DailyCaseVO;

/**
 * 每日一例服务（PRD 4.10 / 4.16 / 8.10）
 *
 * <p>旧版开放作答提交接口（/daily-cases/submit）已随移动端切换到九段病历版下线；
 * 本接口仅保留排期管理与「今日排期」解析（后者被每日病历 DailyMrService 复用）。
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
}
