package com.zhiyu.service;

import com.zhiyu.service.dto.TokenQuotaDTO;
import com.zhiyu.service.dto.internal.TokenUsageReportDTO;
import com.zhiyu.vo.TokenOverviewVO;
import com.zhiyu.vo.TokenQuotaVO;
import com.zhiyu.vo.TokenRankVO;
import com.zhiyu.vo.TokenTrendPointVO;

import java.util.List;

/**
 * Token 用量统计与配额管理（V39）
 *
 * <p>数据由 AI 中台在 llm_client 出口统计后经
 * {@code POST /api/internal/token-usage/report} 上报，
 * 此处只做落库与聚合查询，不主动调用大模型。
 */
public interface TokenUsageService {

    /**
     * 上报一条用量流水
     */
    void report(TokenUsageReportDTO dto);

    /**
     * 用量总览：今日 / 本月 / 累计，含配额告警
     */
    TokenOverviewVO overview();

    /**
     * 近 N 天每日用量趋势
     */
    List<TokenTrendPointVO> trend(int days);

    /**
     * 用量排行
     *
     * @param dimension 聚合维度：model（按模型）或 scene（按场景）
     * @param days      统计天数
     */
    List<TokenRankVO> rank(String dimension, int days);

    /**
     * 配额列表（含本月已用量与告警状态）
     */
    List<TokenQuotaVO> listQuota();

    /**
     * 新增或更新配额
     */
    void saveQuota(TokenQuotaDTO dto);

    /**
     * 删除配额
     */
    void deleteQuota(Long id);
}
