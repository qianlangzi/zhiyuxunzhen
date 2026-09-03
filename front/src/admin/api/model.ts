/**
 * 模型管理 API 模块
 * 后端：ModelManageController /api/v1/admin/models
 *
 * 模型配置存库（ai_model 表），管理端切换「激活」后，AI 中台通过内部接口
 * 热读取「启用且激活」的模型配置，教师端/学生端无需重启 AI 服务即可生效。
 */

import http from './http'
import type { ApiResult } from '../types'

/** 模型能力维度（与后端 ai_model.capability 对齐） */
export const ModelCapability = {
  LLM: 'LLM',
  VISION: 'VISION',
  EMBEDDING: 'EMBEDDING',
  EMBEDDING_MULTI: 'EMBEDDING_MULTI',
} as const
export type ModelCapabilityType = (typeof ModelCapability)[keyof typeof ModelCapability]

export const CAPABILITY_LABELS: Record<string, string> = {
  LLM: '大模型对话',
  VISION: '视觉理解',
  EMBEDDING: '文本向量',
  EMBEDDING_MULTI: '多模态向量',
}

/** 模型分页项（后端 AiModelVO；apiKey 为脱敏值） */
export interface ModelItem {
  id: number
  name: string
  provider: string | null
  capability: string
  baseUrl: string
  apiKey: string | null
  hasApiKey: boolean
  model: string
  dimension: number | null
  timeoutSeconds: number | null
  maxTokens: number | null
  temperature: number | null
  isActive: boolean
  status: number
  description: string | null
  createdAt: string
  updatedAt: string
}

/** 分页响应 */
export interface ModelPage {
  list: ModelItem[]
  total: number
}

/** 新增/更新请求体（后端 AiModelDTO；更新时 apiKey 留空=保留原密钥） */
export interface ModelPayload {
  name: string
  provider?: string
  capability: string
  baseUrl: string
  apiKey?: string
  model: string
  dimension?: number | null
  timeoutSeconds?: number | null
  maxTokens?: number | null
  temperature?: number | null
  status: number
  description?: string
}

/** 连通性测试结果 */
export interface ModelTestResult {
  ok: boolean
  latencyMs?: number
  message: string
  raw?: unknown
}

/** 分页查询模型列表（可按能力过滤；需手动分页时用） */
export async function listModels(
  pageNum: number,
  pageSize: number,
  capability?: string,
): Promise<ModelPage> {
  const { data } = await http.get<ApiResult<ModelPage>>('/api/v1/admin/models', {
    params: {
      pageNum,
      pageSize,
      ...(capability ? { capability } : {}),
    },
  })
  return data.data
}

/** 新增模型 */
export async function createModel(payload: ModelPayload): Promise<ModelItem> {
  const { data } = await http.post<ApiResult<ModelItem>>('/api/v1/admin/models', payload)
  return data.data
}

/** 更新模型 */
export async function updateModel(id: number, payload: ModelPayload): Promise<ModelItem> {
  const { data } = await http.put<ApiResult<ModelItem>>(`/api/v1/admin/models/${id}`, payload)
  return data.data
}

/** 删除模型 */
export async function deleteModel(id: number): Promise<void> {
  const { data } = await http.delete<ApiResult<void>>(`/api/v1/admin/models/${id}`)
  return data.data
}

/** 切换激活（同能力至多一个激活，AI 中台热生效） */
export async function setModelActive(id: number): Promise<void> {
  const { data } = await http.post<ApiResult<void>>(`/api/v1/admin/models/${id}/active`)
  return data.data
}

/** 停用/启用切换 */
export async function toggleModel(id: number): Promise<void> {
  const { data } = await http.post<ApiResult<void>>(`/api/v1/admin/models/${id}/toggle`)
  return data.data
}

/** 连通性测试 */
export async function testModel(id: number): Promise<ModelTestResult> {
  const { data } = await http.post<ApiResult<ModelTestResult>>(`/api/v1/admin/models/${id}/test`)
  return data.data
}