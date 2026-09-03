/**
 * 人数管理 API 模块
 * 后端：AdminUserController + UserImportController /api/v1/admin/users
 *
 * 补齐链路：此前后端只有冻结/解冻/改角色/建审核员 4 个写接口且无列表查询，
 * 前端完全没有接入（0 页面 0 调用）。现在补齐列表 + 统计 + 重置密码 + 批量操作。
 */

import http from './http'
import type { ApiResult } from '../types'

/** 用户列表项（后端 AdminUserVO；手机号已脱敏） */
export interface AdminUserItem {
  id: number
  username: string
  realName: string
  role: number
  roleName: string
  classId: number | null
  className: string | null
  schoolName: string | null
  grade: string | null
  department: string | null
  phone: string | null
  auditStatus: number | null
  status: number
  mustChangePassword: boolean | null
  lastLoginAt: string | null
  createdAt: string | null
}

/** 分页响应（后端 PageResult） */
export interface AdminUserPage {
  list: AdminUserItem[]
  total: number
  page: number
  pageSize: number
}

/** 人数总览（后端 AdminUserStatsVO） */
export interface AdminUserStats {
  totalUsers: number
  studentCount: number
  teacherCount: number
  teachingSecretaryCount: number
  deptHeadCount: number
  adminCount: number
  opsCount: number
  auditorCount: number
  frozenCount: number
  pendingTeacherCount: number
  todayNewUsers: number
  weekNewUsers: number
}

/** 用户列表分页查询 */
export async function listUsers(
  pageNum: number,
  pageSize: number,
  role?: number,
  status?: number,
  keyword?: string,
): Promise<AdminUserPage> {
  const { data } = await http.get<ApiResult<AdminUserPage>>('/api/v1/admin/users', {
    params: { pageNum, pageSize, role: role ?? undefined, status: status ?? undefined, keyword: keyword || undefined },
  })
  return data.data
}

/** 人数总览 */
export async function getUserStats(): Promise<AdminUserStats> {
  const { data } = await http.get<ApiResult<AdminUserStats>>('/api/v1/admin/users/stats')
  return data.data
}

/** 冻结账号 */
export async function freezeUser(id: number): Promise<void> {
  await http.post<ApiResult<void>>(`/api/v1/admin/users/${id}/freeze`)
}

/** 解冻账号 */
export async function unfreezeUser(id: number): Promise<void> {
  await http.post<ApiResult<void>>(`/api/v1/admin/users/${id}/unfreeze`)
}

/** 修改用户角色（仅支持 0-3） */
export async function changeUserRole(id: number, role: number): Promise<void> {
  await http.post<ApiResult<void>>(`/api/v1/admin/users/${id}/role`, null, { params: { role } })
}

/** 重置密码（返回一次性明文新密码） */
export async function resetPassword(id: number): Promise<string> {
  const { data } = await http.post<ApiResult<{ newPassword: string }>>(
    `/api/v1/admin/users/${id}/reset-password`,
  )
  return data.data.newPassword
}

/** 批量冻结（返回实际变更条数） */
export async function batchFreeze(ids: number[]): Promise<number> {
  const { data } = await http.post<ApiResult<{ changed: number }>>(
    '/api/v1/admin/users/batch-freeze',
    { userIds: ids },
  )
  return data.data.changed
}

/** 批量解冻（返回实际变更条数） */
export async function batchUnfreeze(ids: number[]): Promise<number> {
  const { data } = await http.post<ApiResult<{ changed: number }>>(
    '/api/v1/admin/users/batch-unfreeze',
    { userIds: ids },
  )
  return data.data.changed
}

/** 开通普通审核员账号 */
export async function createAuditor(payload: { username: string; realName: string; password?: string }): Promise<void> {
  await http.post<ApiResult<void>>('/api/v1/admin/users/auditor', payload)
}

/** 学生账号 Excel 批量导入（后端 ImportResultVO，成功明细含需分发的临时密码） */
export interface ImportResult {
  successCount: number
  failCount: number
  successes?: Array<{ row: number; username: string; tempPassword: string }>
  failures?: Array<{ row: number; username: string; reason: string }>
}

export async function importStudents(file: File): Promise<ImportResult> {
  const form = new FormData()
  form.append('file', file)
  const { data } = await http.post<ApiResult<ImportResult>>('/api/v1/admin/users/import', form, {
    headers: { 'Content-Type': 'multipart/form-data' },
  })
  return data.data
}
