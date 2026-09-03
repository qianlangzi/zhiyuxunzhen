/**
 * Token 管理 API 模块
 * 后端：TokenManageController /api/v1/admin/token
 *
 * 数据来源：AI 中台 llm_client 出口统计后经 /api/internal/token-usage/report 上报落库，
 * 这里只做聚合查询与配额维护。
 */

import http from './http'
import type { ApiResult } from '../types'

/** 用量总览（后端 TokenOverviewVO） */
export interface TokenOverview {
  todayTokens: number
  monthTokens: number
  totalTokens: number
  todayCalls: number
  monthCalls: number
  avgLatencyMs: number
  monthFailedCalls: number
  monthQuota: number
  monthUsedPercent: number | null
  alerts?: TokenQuotaAlert[]
}

/** 配额告警项 */
export interface TokenQuotaAlert {
  model: string
  usedTokens: number
  monthlyQuota: number
  usedPercent: number
  /** warning：达阈值未超额；exceeded：已超额 */
  level: string
}

/** 趋势点（按天） */
export interface TokenTrendPoint {
  label: string
  totalTokens: number
  promptTokens: number
  completionTokens: number
  calls: number
}

/** 排行项（按模型或场景） */
export interface TokenRankItem {
  name: string
  totalTokens: number
  promptTokens: number
  completionTokens: number
  calls: number
  avgLatencyMs: number
  percent: number
}

/** 配额项 */
export interface TokenQuotaItem {
  id: number
  model: string
  monthlyQuota: number
  warnPercent: number
  status: number
  remark: string | null
  usedTokens: number
  usedPercent: number | null
  warning: boolean
  exceeded: boolean
}

/** 配额保存请求 */
export interface TokenQuotaPayload {
  id?: number
  model: string
  monthlyQuota: number
  warnPercent: number
  status?: number
  remark?: string
}

export async function getTokenOverview(): Promise<TokenOverview> {
  const { data } = await http.get<ApiResult<TokenOverview>>('/api/v1/admin/token/overview')
  return data.data
}

export async function getTokenTrend(days = 30): Promise<TokenTrendPoint[]> {
  const { data } = await http.get<ApiResult<TokenTrendPoint[]>>('/api/v1/admin/token/trend', {
    params: { days },
  })
  return data.data
}

export async function getTokenRank(dimension: 'model' | 'scene', days = 30): Promise<TokenRankItem[]> {
  const { data } = await http.get<ApiResult<TokenRankItem[]>>('/api/v1/admin/token/rank', {
    params: { dimension, days },
  })
  return data.data
}

export async function listTokenQuota(): Promise<TokenQuotaItem[]> {
  const { data } = await http.get<ApiResult<TokenQuotaItem[]>>('/api/v1/admin/token/quota')
  return data.data
}

export async function saveTokenQuota(payload: TokenQuotaPayload): Promise<void> {
  await http.post<ApiResult<void>>('/api/v1/admin/token/quota', payload)
}

export async function deleteTokenQuota(id: number): Promise<void> {
  await http.delete<ApiResult<void>>(`/api/v1/admin/token/quota/${id}`)
}
