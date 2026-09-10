/**
 * 短信服务商配置 API 模块
 * 对应后端 SmsConfigController：/api/v1/admin/sms-config
 *
 * 支持运行时热切换：DB(sys_config.sms.provider) > 环境变量 SMS_PROVIDER，
 * 切换后无需重启后端容器即可生效。
 */

import http from './http'
import type { ApiResult } from '../types'

/** 短信服务商配置与就绪状态（后端 SmsConfigVO） */
export interface SmsConfigVO {
  /** 当前生效：aliyun_auth / juhe / off / '' */
  provider: string
  /** 当前值来源：DB / ENV / NONE */
  source: string
  /** 环境变量注入的默认值（只读参考） */
  envProvider: string
  supported: string[]
  aliyunReady: boolean
  juheReady: boolean
  aliyunSignName: string
  aliyunTemplateCode: string
  juheTplId: string
}

/** 测试发送结果 */
export interface SmsTestResult {
  success: boolean
  provider: string
  message: string
}

/** 服务商中文名 */
export const SMS_PROVIDER_LABEL: Record<string, string> = {
  aliyun_auth: '阿里云短信认证',
  juhe: '聚合数据',
  off: '关闭发送（仅日志）',
}

/** 查询短信服务商配置 */
export async function getSmsConfig(): Promise<SmsConfigVO> {
  const { data } = await http.get<ApiResult<SmsConfigVO>>(
    '/api/v1/admin/sms-config',
  )
  return data.data as SmsConfigVO
}

/** 切换短信服务商（即时生效） */
export async function switchSmsProvider(provider: string): Promise<void> {
  await http.put<ApiResult<void>>('/api/v1/admin/sms-config', { provider })
}

/** 用当前服务商发送一条测试短信 */
export async function testSmsSend(phone: string): Promise<SmsTestResult> {
  const { data } = await http.post<ApiResult<SmsTestResult>>(
    '/api/v1/admin/sms-config/test',
    { phone },
  )
  return (
    data.data ?? { success: true, provider: '', message: '已发送' }
  )
}
