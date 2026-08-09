/**
 * 管理端 Dashboard API
 * 对应后端 DashboardController：GET /api/v1/admin/dashboard
 */

import http from './http'
import type { ApiResult, DashboardVO } from '../types'

/** 获取全局驾驶舱聚合指标 */
export async function getDashboard(): Promise<DashboardVO> {
  const { data } = await http.get<ApiResult<DashboardVO>>(
    '/api/v1/admin/dashboard',
  )
  return data.data
}
