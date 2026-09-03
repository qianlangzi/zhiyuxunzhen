/**
 * AI 配置中心 API 模块（提示词 · Agent · RAG 运行参数 热更新）
 * 后端：AdminAiConfigController /api/v1/admin/ai-config
 *
 * 与模型管理（/api/v1/admin/models）共同构成「AI 配置中心」。
 * 配置存库后，AI 中台通过内部接口周期热拉取「启用且激活」的值，
 * 教师端/学生端无需重启 AI 服务；管理员可在运行态立即应用并核验版本。
 */

import http from './http'
import type { ApiResult } from '../types'

// ==================== 提示词 ====================

/** 提示词分页项（后端 AiPromptVO） */
export interface PromptItem {
  id: number
  name: string // 逻辑键
  version: string | null
  title: string
  description: string | null
  content: string
  isActive: boolean
  status: number
  createdAt: string
  updatedAt: string
}

/** 提示词新增/更新请求（后端 AiPromptDTO） */
export interface PromptPayload {
  name: string
  version?: string
  title: string
  description?: string
  content: string
  status?: number
}

/** 分页查询提示词列表（可按逻辑键过滤） */
export async function listPrompts(
  pageNum: number,
  pageSize: number,
  name?: string,
): Promise<{ list: PromptItem[]; total: number }> {
  const { data } = await http.get<ApiResult<{ list: PromptItem[]; total: number }>>(
    '/api/v1/admin/ai-config/prompts',
    { params: { pageNum, pageSize, ...(name ? { name } : {}) } },
  )
  return data.data
}

/** 新增提示词 */
export async function createPrompt(payload: PromptPayload): Promise<PromptItem> {
  const { data } = await http.post<ApiResult<PromptItem>>('/api/v1/admin/ai-config/prompts', payload)
  return data.data
}

/** 更新提示词 */
export async function updatePrompt(id: number, payload: PromptPayload): Promise<PromptItem> {
  const { data } = await http.put<ApiResult<PromptItem>>(
    `/api/v1/admin/ai-config/prompts/${id}`,
    payload,
  )
  return data.data
}

/** 删除提示词 */
export async function deletePrompt(id: number): Promise<void> {
  const { data } = await http.delete<ApiResult<void>>(`/api/v1/admin/ai-config/prompts/${id}`)
  return data.data
}

/** 切换提示词激活（同 name 至多一个激活，AI 中台热生效） */
export async function setPromptActive(id: number): Promise<void> {
  const { data } = await http.post<ApiResult<void>>(`/api/v1/admin/ai-config/prompts/${id}/active`)
  return data.data
}

/** 提示词停用/启用切换 */
export async function togglePrompt(id: number): Promise<void> {
  const { data } = await http.post<ApiResult<void>>(`/api/v1/admin/ai-config/prompts/${id}/toggle`)
  return data.data
}

// ==================== Agent ====================

/** Agent 分页项（后端 AiAgentVO） */
export interface AgentItem {
  id: number
  code: string // 逻辑键
  name: string
  description: string | null
  promptName: string | null
  promptOverride: string | null
  temperature: number | null
  maxTokens: number | null
  toolsConfig: string | null
  isActive: boolean
  status: number
  createdAt: string
  updatedAt: string
}

/** Agent 新增/更新请求（后端 AiAgentDTO） */
export interface AgentPayload {
  code: string
  name: string
  description?: string
  promptName?: string
  promptOverride?: string
  temperature?: number | null
  maxTokens?: number | null
  toolsConfig?: string
  status?: number
}

/** 分页查询 Agent 列表（可按逻辑键过滤） */
export async function listAgents(
  pageNum: number,
  pageSize: number,
  code?: string,
): Promise<{ list: AgentItem[]; total: number }> {
  const { data } = await http.get<ApiResult<{ list: AgentItem[]; total: number }>>(
    '/api/v1/admin/ai-config/agents',
    { params: { pageNum, pageSize, ...(code ? { code } : {}) } },
  )
  return data.data
}

/** 新增 Agent */
export async function createAgent(payload: AgentPayload): Promise<AgentItem> {
  const { data } = await http.post<ApiResult<AgentItem>>('/api/v1/admin/ai-config/agents', payload)
  return data.data
}

/** 更新 Agent */
export async function updateAgent(id: number, payload: AgentPayload): Promise<AgentItem> {
  const { data } = await http.put<ApiResult<AgentItem>>(
    `/api/v1/admin/ai-config/agents/${id}`,
    payload,
  )
  return data.data
}

/** 删除 Agent */
export async function deleteAgent(id: number): Promise<void> {
  const { data } = await http.delete<ApiResult<void>>(`/api/v1/admin/ai-config/agents/${id}`)
  return data.data
}

/** 切换 Agent 激活（同 code 至多一个激活，AI 中台热生效） */
export async function setAgentActive(id: number): Promise<void> {
  const { data } = await http.post<ApiResult<void>>(`/api/v1/admin/ai-config/agents/${id}/active`)
  return data.data
}

/** Agent 停用/启用切换 */
export async function toggleAgent(id: number): Promise<void> {
  const { data } = await http.post<ApiResult<void>>(`/api/v1/admin/ai-config/agents/${id}/toggle`)
  return data.data
}

// ==================== RAG 运行参数 ====================

/** RAG 运行参数项（后端 AiRuntimeConfigVO） */
export interface RuntimeItem {
  id: number
  configKey: string
  configName: string
  description: string | null
  configType: string // number/switch/float/text
  value: string
  defaultValue: string | null
  min: string | null
  max: string | null
  step: string | null
  isActive: boolean
  createdAt: string
  updatedAt: string
}

/** RAG 运行参数新增/更新请求（后端 AiRuntimeConfigDTO） */
export interface RuntimePayload {
  configKey: string
  configName: string
  description?: string
  configType: string
  value: string
  defaultValue?: string
  min?: string
  max?: string
  step?: string
}

/** 分页查询 RAG 运行参数（可按配置键模糊过滤） */
export async function listRuntime(
  pageNum: number,
  pageSize: number,
  configKey?: string,
): Promise<{ list: RuntimeItem[]; total: number }> {
  const { data } = await http.get<ApiResult<{ list: RuntimeItem[]; total: number }>>(
    '/api/v1/admin/ai-config/runtime',
    { params: { pageNum, pageSize, ...(configKey ? { configKey } : {}) } },
  )
  return data.data
}

/** 保存 RAG 运行参数（按 config_key upsert） */
export async function saveRuntime(payload: RuntimePayload): Promise<RuntimeItem> {
  const { data } = await http.post<ApiResult<RuntimeItem>>('/api/v1/admin/ai-config/runtime', payload)
  return data.data
}

/** 删除 RAG 运行参数 */
export async function deleteRuntime(id: number): Promise<void> {
  const { data } = await http.delete<ApiResult<void>>(`/api/v1/admin/ai-config/runtime/${id}`)
  return data.data
}

// ==================== AI 中台运行态 / 基线 ====================

/** 基线条目（提示词/Agent 通用） */
export interface BaselineItem {
  title?: string
  description?: string | null
  content?: string
  name?: string
  temperature?: number | null
  max_tokens?: number | null
  tools_config?: string
}

/** AI 中台运行态快照（后端经 AiPlatformClient 代理；offline=true 表示 AI 中台不可达） */
export interface AiStatusData {
  offline?: boolean
  app?: { name: string; version: string; env: string; llm_configured: boolean }
  refresh?: {
    last_refresh: Record<string, string | null>
    last_errors: Record<string, string>
    prompt_count: number
    agent_count: number
    runtime_count: number
  }
  modelRegistry?: {
    version: string | null
    last_refresh_at: string | null
    last_error: string | null
    capabilities: string[]
    count: number
    refresh_interval_seconds: number
  }
  refreshIntervalSeconds?: number
  effective?: {
    promptSource: Record<string, { source: string; title: string }>
    agentSource: Record<string, { source: string; name: string }>
    runtime: Record<string, { value: number | string; baseline: number | string; source: string }>
  }
  models?: Record<
    string,
    { capability: string; model: string; baseUrl: string; host: string; configured: boolean; temperature?: number; maxTokens?: number }
  >
}

/** 获取 AI 中台运行态快照 */
export async function getConfigStatus(): Promise<AiStatusData> {
  const { data } = await http.get<ApiResult<AiStatusData>>('/api/v1/admin/ai-config/status')
  return data.data
}

/** 立即触发 AI 中台全量配置刷新并返回刷新结果 */
export async function refreshAiConfig(): Promise<{ ok?: boolean; modelRegistry?: AiStatusData['modelRegistry'] }> {
  const { data } = await http.post<ApiResult<{ ok?: boolean; modelRegistry?: AiStatusData['modelRegistry'] }>>(
    '/api/v1/admin/ai-config/refresh',
  )
  return data.data
}

/** 获取 AI 中台内置提示词基线 */
export async function getPromptBaseline(): Promise<Record<string, BaselineItem>> {
  const { data } = await http.get<ApiResult<Record<string, BaselineItem>>>(
    '/api/v1/admin/ai-config/baseline/prompts',
  )
  return data.data
}

/** 获取 AI 中台内置 Agent 基线 */
export async function getAgentBaseline(): Promise<Record<string, BaselineItem>> {
  const { data } = await http.get<ApiResult<Record<string, BaselineItem>>>(
    '/api/v1/admin/ai-config/baseline/agents',
  )
  return data.data
}

/** 一键导入提示词基线（names 为空导入全部）；返回导入数量 */
export async function importPromptBaseline(names?: string[]): Promise<number> {
  const { data } = await http.post<ApiResult<number>>(
    '/api/v1/admin/ai-config/baseline/prompts/import',
    names ?? [],
  )
  return data.data
}

/** 一键导入 Agent 基线（codes 为空导入全部）；返回导入数量 */
export async function importAgentBaseline(codes?: string[]): Promise<number> {
  const { data } = await http.post<ApiResult<number>>(
    '/api/v1/admin/ai-config/baseline/agents/import',
    codes ?? [],
  )
  return data.data
}

// ==================== 最近模型事件 ====================

/** AI 模型运行事件（管理端「最近模型事件」视图；不含任何密钥） */
export interface ModelEventItem {
  id: number
  eventType: string // model_error / degradation / timeout / recovered / info
  modelName: string | null
  capability: string | null // LLM / VISION / EMBEDDING / EMBEDDING_MULTI / fallback
  errorMessage: string | null // 业务可读文案
  detailJson: string | null
  traceId: string | null
  recovered: boolean
  createdAt: string
}

/** 获取最近 N 条模型运行事件 */
export async function getModelEvents(limit = 20): Promise<ModelEventItem[]> {
  const { data } = await http.get<ApiResult<ModelEventItem[]>>(
    '/api/v1/admin/ai-config/model-events',
    { params: { limit } },
  )
  return data.data
}
