/**
 * 审计日志 API 模块
 * 对应后端 AuditLogController：/api/v1/admin/audit-logs
 */

import http from './http'
import type { ApiResult } from '../types'

/** 审计日志分页项（后端 AuditLogVO） */
export interface AuditLogItem {
  id: number
  operatorId: number
  operatorName: string
  operatorRole: number
  action: string
  targetType: string
  targetId: number | null
  beforeJson: string | null
  afterJson: string | null
  ipAddress: string | null
  createdAt: string
}

/** 审计日志分页响应 */
export interface AuditLogPage {
  list: AuditLogItem[]
  total: number
}

/** 分页查询审计日志 */
export async function listAuditLogs(
  pageNum: number,
  pageSize: number,
  action?: string,
): Promise<AuditLogPage> {
  const { data } = await http.get<ApiResult<AuditLogPage>>(
    '/api/v1/admin/audit-logs',
    { params: { pageNum, pageSize, ...(action ? { action } : {}) } },
  )
  return data.data
}