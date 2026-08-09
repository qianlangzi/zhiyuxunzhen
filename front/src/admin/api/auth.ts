/**
 * 认证 API 模块
 * 对应后端 AuthController：/api/v1/auth/*
 */

import http from './http'
import type { ApiResult, LoginRequest, LoginResponse, UserInfoVO } from '../types'

/** 登录（用户名 + 密码） */
export async function login(req: LoginRequest): Promise<LoginResponse> {
  const { data } = await http.post<ApiResult<LoginResponse>>(
    '/api/v1/auth/login',
    req,
  )
  return data.data
}

/** 获取当前登录用户信息（/auth/me 返回 UserInfoVO，主键字段是 id） */
export async function me(): Promise<UserInfoVO> {
  const { data } = await http.get<ApiResult<UserInfoVO>>('/api/v1/auth/me')
  return data.data
}

/** 修改密码（首次登录强制改密 / 用户主动改密） */
export async function changePassword(
  oldPassword: string,
  newPassword: string,
): Promise<void> {
  await http.put<ApiResult<void>>('/api/v1/auth/password', {
    oldPassword,
    newPassword,
  })
}

/** 登出（后端仅清除 UserContext，客户端负责清 token） */
export async function logout(): Promise<void> {
  try {
    await http.post<ApiResult<void>>('/api/v1/auth/logout')
  } catch {
    // 登出失败不阻塞前端清除流程
  }
}
