package com.zhiyu.service;

import com.zhiyu.common.result.PageResult;
import com.zhiyu.service.dto.DailyMrHintDTO;
import com.zhiyu.service.dto.DailyMrSubmitDTO;
import com.zhiyu.vo.DailyMrBankItemVO;
import com.zhiyu.vo.DailyMrDetailVO;
import com.zhiyu.vo.DailyMrTodayVO;

import java.util.List;
import java.util.Map;

/**
 * 每日病历服务（每日一例升级版）：九段书写 + AI 段落教练 + 结构化批阅 + 题库/打卡
 */
public interface DailyMrService {

    /** 今日卡：今日排期 + 我的最新记录 + 连续打卡 */
    DailyMrTodayVO todayMr();

    /** 病历题库：往期每日一例列表（done: null全部 1已做 0未做） */
    PageResult<DailyMrBankItemVO> bank(int pageNum, int pageSize, Integer done);

    /** 题目详情：病例材料 + 九段定义 + 我的提交记录（提交过才下发标准答案/参考病历） */
    DailyMrDetailVO detail(Long scheduleId);

    /** 段落教练：AI 三级提示梯度（追问→定向提示→示范片段） */
    Map<String, Object> hint(DailyMrHintDTO dto);

    /** 提交病历：AI 结构化批阅 → 落库 record/segment/defect，返回批阅结果 */
    Map<String, Object> submit(DailyMrSubmitDTO dto);

    /** 打卡日历：指定年份有提交记录的日期 + 连续天数 */
    Map<String, Object> calendar(Integer year);

    // ==================== 教师端 ====================

    /** 最近期次列表（批阅台选期用，默认取最近 30 期） */
    List<Map<String, Object>> schedules(int limit);

    /** 批阅台：某期学生病历列表（AI 初筛置信度透出，教师只重点看低置信/高危缺陷） */
    PageResult<Map<String, Object>> teacherRecords(Long scheduleId, int pageNum, int pageSize);

    /** 复核：教师改分/评语，覆盖展示分 */
    Map<String, Object> teacherReview(Long recordId, Double score, String comment);

    /** 班级缺陷统计：按缺陷标签聚合（scheduleId 为空则统计全部期次） */
    List<Map<String, Object>> defectStats(Long scheduleId);
}
