/**
 * 管理端 Dashboard API
 * 对应后端 DashboardController：GET /api/v1/admin/dashboard
 */

import http from './http'
import type { ApiResult, DashboardVO, TrendPointVO, UserOverviewVO } from '../types'

/** 获取全局驾驶舱聚合指标 */
export async function getDashboard(): Promise<DashboardVO> {
  const { data } = await http.get<ApiResult<DashboardVO>>(
    '/api/v1/admin/dashboard',
  )
  return data.data
}

/** 用户数据看板总览：注册/活跃/在线 */
export async function getUserOverview(): Promise<UserOverviewVO> {
  const { data } = await http.get<ApiResult<UserOverviewVO>>(
    '/api/v1/admin/dashboard/user-overview',
  )
  return data.data
}

/** 某日在线人数走势（5 分钟采样折线） */
export async function getOnlineTrend(date?: string): Promise<TrendPointVO[]> {
  const { data } = await http.get<ApiResult<TrendPointVO[]>>(
    '/api/v1/admin/dashboard/online-trend',
    { params: date ? { date } : {} },
  )
  return data.data
}

/** 近 N 天每日新增注册趋势 */
export async function getRegisterTrend(days = 30): Promise<TrendPointVO[]> {
  const { data } = await http.get<ApiResult<TrendPointVO[]>>(
    '/api/v1/admin/dashboard/register-trend',
    { params: { days } },
  )
  return data.data
}

/** 近 N 天每日活跃(DAU)与峰值在线趋势 */
export async function getActiveTrend(days = 30): Promise<TrendPointVO[]> {
  const { data } = await http.get<ApiResult<TrendPointVO[]>>(
    '/api/v1/admin/dashboard/active-trend',
    { params: { days } },
  )
  return data.data
}
