/**
 * 管理端类型定义（与后端 DTO/VO 对齐）
 */

// ---------- 统一响应体（后端 R<T>）----------
export interface ApiResult<T> {
  code: number
  message: string
  data: T
}

// ---------- 认证相关 ----------

/** 登录请求（后端 LoginRequest） */
export interface LoginRequest {
  username: string
  password: string
}

/** 登录响应（后端 LoginResponse） */
export interface LoginResponse {
  token: string
  refreshToken: string
  expiresIn: number
  userId: number
  username: string
  realName: string
  role: number
  auditStatus: number
  /** 是否需要强制修改密码（批量导入学生首次登录时为 true） */
  mustChangePassword?: boolean
}

/** 刷新 token 请求（后端 RefreshTokenRequest） */
export interface RefreshTokenRequest {
  refreshToken: string
}

/** 当前用户信息（后端 UserInfoVO，主键字段是 id） */
export interface UserInfoVO {
  id: number
  username: string
  realName: string
  role: number
  classId: number | null
  auditStatus: number
  status: number
  phone: string | null
  avatar: string | null
  authorizedClasses: string | null
  lastLoginAt: string | null
  /** 是否需要强制修改密码（页面刷新后从 /auth/me 恢复） */
  mustChangePassword?: boolean
}

// ---------- 错误码（与后端 ResultCode 对齐）----------
export const ResultCode = {
  SUCCESS: 0,
  UNAUTHORIZED: 1001,       // 未登录或 token 无效
  TOKEN_EXPIRED: 1002,      // token 已过期
  FORBIDDEN: 1003,          // 无权限访问
  BAD_REQUEST: 1400,
  NOT_FOUND: 1404,
  VALIDATION_FAILED: 1422,
  USERNAME_OR_PASSWORD_ERROR: 2001,
  ACCOUNT_FROZEN: 2002,     // 账号已冻结
  PASSWORD_SAME_AS_OLD: 2014, // 新密码不能与原密码相同
  INTERNAL_ERROR: 5000,
} as const

// ---------- 角色枚举（与后端 SysUser.role 对齐）----------
export const Role = {
  STUDENT: 0,
  TEACHER: 1,
  TEACHING_SECRETARY: 2,
  DEPT_HEAD: 3,
  ADMIN: 4,
  OPS: 5,
} as const

/** 管理端允许登录的角色（2-5） */
export const ADMIN_ROLES = [2, 3, 4, 5]

// ---------- 导航菜单 ----------

export interface NavItem {
  label: string
  path: string
  icon: string
  /** 允许访问此菜单的角色列表 */
  roles: number[]
}

/**
 * 管理端菜单矩阵（P0 最小权限）
 * role 2（教学秘书）：暂无可用功能页
 * role 3（教研室主任）：仅驾驶舱
 * role 4（管理员）：全部页面
 * role 5（运维）：仅驾驶舱
 */
export const NAV_ITEMS: NavItem[] = [
  { label: '全局驾驶舱', path: '/', icon: 'DataBoard', roles: [3, 4, 5] },
  { label: '审核中心', path: '/audits', icon: 'Checked', roles: [4] },
  { label: '系统配置', path: '/config', icon: 'Setting', roles: [4] },
  { label: '审计日志', path: '/logs', icon: 'Tickets', roles: [4] },
]

/** 根据角色获取默认落地页 */
export function getDefaultPath(role: number): string {
  if (role === 2) return '/no-access'
  // role 3/4/5 默认驾驶舱
  if (role === 3 || role === 4 || role === 5) return '/'
  return '/no-access'
}

/** 根据角色获取允许访问的菜单列表 */
export function getAllowedMenus(role: number): NavItem[] {
  return NAV_ITEMS.filter((item) => item.roles.includes(role))
}

// ---------- Dashboard ----------

/** 全局驾驶舱聚合指标（后端 DashboardVO） */
export interface DashboardVO {
  todayActiveStudents: number
  activeTeachers: number
  chatSessionCount: number
  assignmentSubmitCount: number
  pendingCaseAuditCount: number
  pendingTeacherAuditCount: number
  officialCaseCount: number
}

// ---------- 自定义错误 ----------

/** 业务错误（code != 0） */
export class ApiError extends Error {
  constructor(public code: number, message: string) {
    super(message)
    this.name = 'ApiError'
  }
}
