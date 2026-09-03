/**
 * 教材管理 API 模块
 * 对应后端 TextbookController：/api/v1/admin/textbooks/*
 */

import http from './http'
import type { ApiResult } from '../types'

/** 教材入库状态 */
export enum IngestStatus {
  NONE = 0, // 未入库
  PROCESSING = 1, // 处理中
  DONE = 2, // 已入库
  FAILED = 3, // 失败
}

/** 教材上下架状态 */
export enum TextbookStatus {
  OFF_SHELF = 0, // 下架
  ON_SHELF = 1, // 上架
}

/** 教材分页项（列表行数据） */
export interface TextbookItem {
  id: number
  title: string
  edition: string | null
  department: string
  author: string
  publisher: string | null
  coverUrl: string | null
  fileUrl: string | null
  description: string | null
  pageCount: number | null
  /** 0下架 1上架 */
  status: number
  /** 0未入库/1处理中/2已入库/3失败 */
  ingestStatus: number
  /** 最近一次失败原因 */
  ingestError: string | null
  lastIngestAt: string | null
  /** AI 中台最近一次入库任务 ID */
  ingestionId: string | null
  /** 累计触发入库次数（含重试/重新入库） */
  ingestRetryCount: number | null
  creatorId: number
  creatorName: string
  createdAt: string
}

/** 教材分页响应（后端分页 VO） */
export interface TextbookPage {
  list: TextbookItem[]
  total: number
}

/** 触发入库返回（后端 VO） */
export interface IngestResult {
  /** AI 中台任务 UUID */
  ingestionId: string
  /** PENDING/QUEUED 等任务状态 */
  status: string
}

/** AI 入库任务详情（AI 中台任务快照 + 本地入库状态兜底） */
export interface IngestTaskDetail {
  ingestionId: string | null
  /** PENDING/RUNNING/SUCCEEDED/FAILED_RETRYABLE/FAILED_FINAL/NONE/AI_TASK_UNAVAILABLE */
  status: string
  /** 已尝试次数 */
  attempts: number | null
  /** 最近错误消息 */
  errorMessage: string | null
  /** 本地入库状态（0-3），AI 任务不可达时用于兜底判断 */
  ingestStatus?: number | null
}

/** 分页查询教材列表 */
export async function listTextbooks(
  pageNum: number,
  pageSize: number,
): Promise<TextbookPage> {
  const { data } = await http.get<ApiResult<TextbookPage>>(
    '/api/v1/admin/textbooks',
    { params: { pageNum, pageSize } },
  )
  return data.data
}

/** 触发教材入向量库 */
export async function triggerIngest(textbookId: number): Promise<IngestResult> {
  const { data } = await http.post<ApiResult<IngestResult>>(
    `/api/v1/admin/textbooks/${textbookId}/ingest`,
  )
  return data.data
}

/** 切换教材上架/下架状态 */
export async function toggleTextbookStatus(textbookId: number): Promise<void> {
  const { data } = await http.post<ApiResult<void>>(
    `/api/v1/admin/textbooks/${textbookId}/toggle-status`,
  )
  return data.data
}

/** 查询教材最近一次入库任务详情（任务 ID/尝试次数/错误信息） */
export async function getIngestTaskDetail(textbookId: number): Promise<IngestTaskDetail> {
  const { data } = await http.get<ApiResult<IngestTaskDetail>>(
    `/api/v1/admin/textbooks/${textbookId}/ingest-task`,
  )
  return data.data
}
