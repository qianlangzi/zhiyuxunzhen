/**
 * 管理端通用格式化工具
 *
 * 设计要点：
 * 1. 后端默认返回 ISO-8601（带 T 和毫秒的 UTC/Local 字符串），前端的 `new Date()` 可直接解析。
 *    但展示时去掉 T/毫秒/秒级能显著提升可读性，所以这里统一格式化。
 * 2. 全部用 zh-CN locale，绝不用 Date.prototype.toString() 之类输出英文月份。
 * 3. 解析失败统一返回 '—'，绝不返回 Invalid Date。
 */

/** 安全解析日期：解析失败或空值返回 null */
function parseDate(input: unknown): Date | null {
  if (input == null) return null
  if (input instanceof Date) {
    return Number.isNaN(input.getTime()) ? null : input
  }
  const s = String(input).trim()
  if (!s || s === '-' || s.toLowerCase() === 'null') return null
  // 兼容 "2026-09-02 07:05:53"（已 replace 过的）与 "2026-09-02T07:05:53"
  const normalized = s.includes(' ') && !s.includes('T') ? s.replace(' ', 'T') : s
  const d = new Date(normalized)
  return Number.isNaN(d.getTime()) ? null : d
}

/** 补零：1 → "01" */
function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`
}

/**
 * 完整日期时间：YYYY-MM-DD HH:mm
 * 用于表格、详情等正式展示位置。
 */
export function fmtDateTime(input: unknown): string {
  const d = parseDate(input)
  if (!d) return '—'
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())} ${pad2(d.getHours())}:${pad2(d.getMinutes())}`
}

/**
 * 仅日期：YYYY-MM-DD
 */
export function fmtDate(input: unknown): string {
  const d = parseDate(input)
  if (!d) return '—'
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`
}

/**
 * 仅时间：HH:mm
 */
export function fmtTimeOnly(input: unknown): string {
  const d = parseDate(input)
  if (!d) return '—'
  return `${pad2(d.getHours())}:${pad2(d.getMinutes())}`
}

/**
 * 相对时间（"刚刚 / 3 分钟前 / 2 小时前 / 昨天 / 5 天前 / 直接显示日期"）
 * 用于审计日志、最近操作等需要「最近多久前」语义的场景。
 */
export function fmtRelative(input: unknown): string {
  const d = parseDate(input)
  if (!d) return '—'
  const diff = Date.now() - d.getTime()
  if (diff < 0) return fmtDateTime(d)
  if (diff < 60_000) return '刚刚'
  if (diff < 3_600_000) return `${Math.floor(diff / 60_000)} 分钟前`
  if (diff < 86_400_000) return `${Math.floor(diff / 3_600_000)} 小时前`
  if (diff < 7 * 86_400_000) {
    const dayStart = new Date(); dayStart.setHours(0, 0, 0, 0)
    const dStart = new Date(d); dStart.setHours(0, 0, 0, 0)
    const delta = Math.round((dayStart.getTime() - dStart.getTime()) / 86_400_000)
    if (delta === 1) return '昨天'
    if (delta > 1) return `${delta} 天前`
  }
  return fmtDate(d)
}

/**
 * el-table-column 的 :formatter 回调：与 Element Plus 签名一致
 *   row, column, cellValue, index
 */
export function tableDateTime(_row: unknown, _col: unknown, cell: unknown): string {
  return fmtDateTime(cell)
}

export function tableDate(_row: unknown, _col: unknown, cell: unknown): string {
  return fmtDate(cell)
}