/**
 * 系统配置 API 模块
 * 对应后端 SysConfigController：/api/v1/admin/sys-config
 */

import http from './http'
import type { ApiResult } from '../types'

/** 系统配置项（后端 SysConfigVO） */
export interface SysConfigItem {
  id: number
  configKey: string
  configValue: string
  /** MODEL / SAFETY / DAILY_CASE / TOKEN_BUDGET */
  configType: string | null
  updatedAt: string | null
}

/** 查询全部系统配置 */
export async function listSysConfigs(): Promise<SysConfigItem[]> {
  const { data } = await http.get<ApiResult<SysConfigItem[]>>(
    '/api/v1/admin/sys-config',
  )
  return data.data ?? []
}

/** 新增/更新系统配置（upsert） */
export async function saveSysConfig(
  configKey: string,
  configValue: string,
  configType: string,
): Promise<void> {
  await http.put<ApiResult<void>>('/api/v1/admin/sys-config', {
    configKey,
    configValue,
    configType,
  })
}