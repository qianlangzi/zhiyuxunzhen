/**
 * 基础题库审核 API 模块
 * 对应后端 QuestionAuditController：/api/v1/admin/question-audits/*
 */

import http from './http'
import type { ApiResult } from '../types'

/** 待审核题库分页项（列表行数据） */
export interface QuestionAuditItem {
  questionId: number
  questionType: string
  department: string
  knowledgeTag: string
  title: string
  difficulty: number
  submitterId: number
  submitterName: string
  /** 1待审核 2通过 3驳回 */
  auditStatus: number
  createdAt: string
}

/** 待审核题库分页响应（后端分页 VO） */
export interface QuestionAuditPage {
  list: QuestionAuditItem[]
  total: number
}

/** 题库审核详情（后端详情 VO） */
export interface QuestionAuditDetail {
  id: number
  questionType: string
  department: string
  knowledgeTag: string
  title: string
  options: string[]
  answer: string
  explanation: string
  difficulty: number
  sourceTextbookId: number | null
  rejectReason: string | null
  createdAt: string
}

/** 分页查询题库审核（auditStatus 可选过滤：1待审核 2通过 3驳回） */
export async function listQuestionAudits(
  pageNum: number,
  pageSize: number,
  auditStatus?: number,
): Promise<QuestionAuditPage> {
  const { data } = await http.get<ApiResult<QuestionAuditPage>>(
    '/api/v1/admin/question-audits',
    { params: { pageNum, pageSize, ...(auditStatus !== undefined ? { auditStatus } : {}) } },
  )
  return data.data
}

/** 获取题库审核详情 */
export async function getQuestionAuditDetail(
  questionId: number,
): Promise<QuestionAuditDetail> {
  const { data } = await http.get<ApiResult<QuestionAuditDetail>>(
    `/api/v1/admin/question-audits/${questionId}/detail`,
  )
  return data.data
}

/** 通过审核 */
export async function approveQuestion(questionId: number): Promise<void> {
  const { data } = await http.post<ApiResult<void>>(
    `/api/v1/admin/question-audits/${questionId}/approve`,
  )
  return data.data
}

/** 驳回审核（携带驳回原因） */
export async function rejectQuestion(
  questionId: number,
  body: { reason: string },
): Promise<void> {
  const { data } = await http.post<ApiResult<void>>(
    `/api/v1/admin/question-audits/${questionId}/reject`,
    body,
  )
  return data.data
}