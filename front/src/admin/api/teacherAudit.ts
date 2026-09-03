/**
 * 审核中心 API 模块
 * 教师审核：TeacherAuditController /api/v1/admin/teacher-audits/*
 * 病例审核：CaseAuditController /api/v1/admin/case-audits/*
 */

import http from './http'
import type { ApiResult } from '../types'

// ---------- 教师资质审核 ----------

/** 教师审核分页项（后端 TeacherAuditVO） */
export interface TeacherAuditItem {
  userId: number
  username: string
  realName: string
  /** 脱敏手机号 */
  phone: string
  certificateNo: string
  department: string
  /** 0未提交 1待审核 2通过 3驳回 */
  auditStatus: number
  createdAt: string
}

/** 教师审核分页响应 */
export interface TeacherAuditPage {
  list: TeacherAuditItem[]
  total: number
}

/** 分页查询教师审核列表（auditStatus 可选过滤） */
export async function listTeacherAudits(
  pageNum: number,
  pageSize: number,
  auditStatus?: number,
): Promise<TeacherAuditPage> {
  const { data } = await http.get<ApiResult<TeacherAuditPage>>(
    '/api/v1/admin/teacher-audits',
    { params: { pageNum, pageSize, ...(auditStatus !== undefined ? { auditStatus } : {}) } },
  )
  return data.data
}

/** 教师资质审核详情（完整资质信息，列表页脱敏手机号，此处为完整号码供联系） */
export interface TeacherAuditDetail {
  userId: number
  username: string
  realName: string
  phone: string | null
  idCard: string | null
  department: string | null
  schoolName: string | null
  grade: string | null
  className: string | null
  teacherCertificateNo: string | null
  teacherCertificateImage: string | null
  avatar: string | null
  /** 0正常 1冻结 */
  status: number
  /** 0未提交 1待审核 2通过 3驳回 */
  auditStatus: number
  createdAt: string | null
  lastLoginAt: string | null
}

/** 查询教师资质审核详情 */
export async function getTeacherAuditDetail(userId: number): Promise<TeacherAuditDetail> {
  const { data } = await http.get<ApiResult<TeacherAuditDetail>>(
    `/api/v1/admin/teacher-audits/${userId}/detail`,
  )
  return data.data
}

/** 审核通过教师资质 */
export async function approveTeacher(userId: number): Promise<void> {
  const { data } = await http.post<ApiResult<void>>(
    `/api/v1/admin/teacher-audits/${userId}/approve`,
  )
  return data.data
}

/** 驳回教师资质（携带原因） */
export async function rejectTeacher(
  userId: number,
  body: { reason: string },
): Promise<void> {
  const { data } = await http.post<ApiResult<void>>(
    `/api/v1/admin/teacher-audits/${userId}/reject`,
    body,
  )
  return data.data
}

// ---------- 病例审核 ----------

/** 病例审核分页项（后端 CaseAuditVO） */
export interface CaseAuditItem {
  caseId: number
  title: string
  department: string
  /** 1简单 2标准 3困难 */
  difficulty: number
  creatorId: number
  creatorName: string
  /** 1待审核 2通过 3驳回 */
  auditStatus: number
  createdAt: string
}

/** 病例审核分页响应 */
export interface CaseAuditPage {
  list: CaseAuditItem[]
  total: number
}

/** 分页查询病例审核列表（auditStatus 可选过滤：1待审核 2通过 3驳回） */
export async function listCaseAudits(
  pageNum: number,
  pageSize: number,
  auditStatus?: number,
): Promise<CaseAuditPage> {
  const { data } = await http.get<ApiResult<CaseAuditPage>>(
    '/api/v1/admin/case-audits',
    { params: { pageNum, pageSize, ...(auditStatus !== undefined ? { auditStatus } : {}) } },
  )
  return data.data
}

/** 病例审核详情（完整病例内容，含各 JSON 配置原文） */
export interface CaseAuditDetail {
  caseId: number
  title: string
  department: string
  /** 1简单 2标准 3困难 */
  difficulty: number
  creatorId: number
  creatorName: string | null
  /** 患者画像 JSON */
  patientProfile: string | null
  hiddenDisease: string | null
  /** 知识点标签 JSON 数组 */
  knowledgeTags: string | null
  /** 检查项目 JSON */
  presetExams: string | null
  /** 标准路径 JSON */
  standardPath: string | null
  referenceAnswer: string | null
  /** 评分要点 JSON 数组 */
  scoringPoints: string | null
  sourceCaseId: number | null
  /** 1待审核 2通过 3驳回 */
  adminAuditStatus: number
  createdAt: string
}

/** 查询病例审核详情 */
export async function getCaseAuditDetail(caseId: number): Promise<CaseAuditDetail> {
  const { data } = await http.get<ApiResult<CaseAuditDetail>>(
    `/api/v1/admin/case-audits/${caseId}/detail`,
  )
  return data.data
}

/** 病例审核通过 */
export async function approveCase(caseId: number): Promise<void> {
  const { data } = await http.post<ApiResult<void>>(
    `/api/v1/admin/case-audits/${caseId}/approve`,
  )
  return data.data
}

/** 病例审核驳回 */
export async function rejectCase(caseId: number): Promise<void> {
  const { data } = await http.post<ApiResult<void>>(
    `/api/v1/admin/case-audits/${caseId}/reject`,
  )
  return data.data
}