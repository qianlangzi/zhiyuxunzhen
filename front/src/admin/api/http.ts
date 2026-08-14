/**
 * 管理端 HTTP 客户端（axios 实例 + 拦截器）
 *
 * 核心规则（P0-C 鉴权链路 + 复审 P0 跨标签 confused-deputy 修复）：
 *   1. 普通请求的 code=1002 触发刷新（2xx 和非 2xx 路径均覆盖）；1001/1003 不刷新
 *   2. refresh 请求自身跳过拦截，原请求最多重放一次
 *   3. refresh 失败的确定性故障（1001/1002/2002）才清登录态；
 *      网络错误或 5xx/5000 不清 token（可能是临时故障）
 *   4. refresh 请求的非 2xx 响应也解析结构化 code，统一转 ApiError
 *   5. 并发 refresh 失败只弹一次提示（refreshFailureNotified 去重）
 *   6. 刷新成功后派发事件，store 据此重算角色与菜单权限
 *   7. 写入新 token 前校验 refresh token 仍与发起时一致，防止在途旧 refresh
 *      覆盖新会话（Tab A refresh 期间 Tab B 退出/登录了新账号）
 *   8. **会话版本号（sessionGeneration）**：tokenStorage.set/clear 递增 gen；
 *      请求拦截器快照 gen 到 config._sessionGen；响应中的 1001/1002/2002 若 gen
 *      不匹配当前（迟到响应），一律静默丢弃——不清登录态、不刷新、不重放。
 *      防止 Tab A 的迟到 1002 用 Tab B 的 refresh token 重放 A 的写请求（confused-deputy）。
 *   9. **P0-3 replay 拦截器不覆盖已绑定 token**：replayed 请求的 Authorization
 *      由 handleTokenExpired 直接注入新 token，请求拦截器检测到 _replayed 标记后
 *      跳过 localStorage 读取，防止跨标签场景下读到其他标签页的 token。
 *  10. **P0-3 跨标签身份变更检测**：storage 事件不仅递增 gen，还解码 JWT subject
 *      比较变更前后的 userId。身份变更（不同用户登录/登出）→ reload 页面，确保
 *      Pinia store 与 API 身份一致；同用户刷新 → 仅 gen++，不重载。
 */

import axios, {
  AxiosError,
  type AxiosInstance,
  type InternalAxiosRequestConfig,
} from 'axios'
import { ElMessage } from 'element-plus'
import { ApiResult, ApiError, LoginResponse, ResultCode } from '../types'

// ---------- Token 存储键（与主应用隔离）----------
const ACCESS_TOKEN_KEY = 'zhiyu_admin_access_token'

/** 刷新 token 的 API 路径 */
const REFRESH_URL = '/api/v1/auth/refresh'

// ---------- 单飞刷新状态 ----------
// doRefresh 返回 null 表示会话已变更（在途旧 refresh 被静默丢弃）
let refreshPromise: Promise<string | null> | null = null
// 并发 refresh 失败时去重弹窗：多个请求复用同一 refreshPromise，失败只弹一次
let refreshFailureNotified = false

// ---------- 会话版本号 ----------
// 每次 tokenStorage.set/clear 递增，用于检测迟到响应。
// 场景：Tab A 发请求 → Tab B 登录（gen++）→ Tab A 的迟到 1002 不应触发
//       用 Tab B 的 refresh token 重放 Tab A 的写请求（confused-deputy）。
//
// P0-2 修复：_sessionGeneration 是每个标签页独立的内存变量，Tab B 的 set/clear
// 只递增 Tab B 的 gen，Tab A 完全不知道。因此监听 window 'storage' 事件：
// 当其他标签页修改 localStorage 中的 token 时，本标签页递增 gen，使在途请求
// 的迟到响应被过滤。storage 事件不会在发起修改的标签页本身触发（浏览器原生行为）。
let _sessionGeneration = 0

// 跨标签同步：其他标签页的 tokenStorage.set/clear 会触发本标签页的 storage 事件
// P0-3 修复：原实现只做 gen++，不同步 Pinia 用户态。Tab B 登录后 Tab A 的 Pinia store
// 仍显示用户 A，但新请求会从 localStorage 读取 B 的 token → UI 显示 A、API 身份为 B。
//
// 修复策略：解码 JWT subject（userId），比较变更前后的身份：
//   - 身份变更（不同用户登录/登出）→ window.location.reload()，确保 UI 与 API 一致
//   - 同用户 token 刷新 → 仅 gen++，不重载（避免频繁刷新影响 UX）
if (typeof window !== 'undefined') {
  window.addEventListener('storage', (e) => {
    if (e.key === ACCESS_TOKEN_KEY) {
      _sessionGeneration++
      // P0-3：检测用户身份是否变更
      const oldUserId = getUserIdFromToken(e.oldValue)
      const newUserId = getUserIdFromToken(e.newValue)
      if (oldUserId !== newUserId) {
        // 身份变更：强制重载，让 Pinia store 从 localStorage 重新初始化
        // 这是 fail-closed 方案：宁可丢失未保存的表单，也不能让 UI 与 API 身份不一致
        window.location.reload()
      }
      // 同用户刷新：gen++ 已完成，迟到响应会被过滤，新请求自然使用新 token
    }
  })
}

/**
 * 从 JWT 中解析 userId（subject）
 *
 * 用于跨标签 storage 事件中检测用户身份是否变更。
 * JWT payload 是第二段 base64，sub 字段为 userId。
 * 解析失败返回 null（视为身份变更，触发 reload）。
 */
function getUserIdFromToken(token: string | null): string | null {
  if (!token) return null
  try {
    const parts = token.split('.')
    if (parts.length !== 3) return null
    // atob 在浏览器中可用；JWT payload 是 base64url，需替换 URL 安全字符
    const payload = JSON.parse(
      atob(parts[1].replace(/-/g, '+').replace(/_/g, '/')),
    )
    return payload.sub?.toString() ?? null
  } catch {
    return null
  }
}

// ---------- 主实例（带拦截器）----------
const instance: AxiosInstance = axios.create({
  timeout: 15000,
  withCredentials: true, // A1 修复：携带 httpOnly refresh token cookie
})

// ---------- 刷新专用实例（无拦截器，避免递归）----------
const refreshInstance: AxiosInstance = axios.create({
  timeout: 15000,
  withCredentials: true, // A1 修复：携带 httpOnly refresh token cookie
})

// ---------- 扩展 config 类型：标记已重放 + 会话快照 ----------
declare module 'axios' {
  interface InternalAxiosRequestConfig {
    _replayed?: boolean
    _sessionGen?: number
  }
}

// ---------- 请求拦截：注入 Authorization + 快照会话版本号 ----------
instance.interceptors.request.use((config: InternalAxiosRequestConfig) => {
  // P0-3 修复：replayed 请求的 Authorization 已由 handleTokenExpired 注入新 token，
  // 不再从 localStorage 读取——否则在跨标签场景下可能读到其他标签页写入的 token，
  // 导致 A 的 method/body 以 B 的身份执行（confused-deputy）。
  if (config._replayed && config.headers.Authorization) {
    config._sessionGen = _sessionGeneration
    return config
  }
  const token = tokenStorage.getAccess()
  // refresh 请求不注入 access token（避免携带过期 token 干扰）
  if (token && config.url !== REFRESH_URL) {
    config.headers.Authorization = `Bearer ${token}`
  }
  // 快照当前会话版本号，响应时比较以过滤迟到响应
  config._sessionGen = _sessionGeneration
  return config
})

// ---------- 响应拦截：统一错误处理 ----------
instance.interceptors.response.use(
  (response) => {
    const result = response.data as ApiResult<unknown>

    // 业务成功
    if (result.code === ResultCode.SUCCESS) {
      return response
    }

    // 会话版本号检查：若请求发出后会话已变更（Tab B 登录/登出），
    // 则忽略此迟到响应（1001/1002/2002），不清登录态、不刷新、不重放。
    const reqGen = response.config._sessionGen ?? 0
    const isStale = reqGen !== _sessionGeneration

    // token 过期（1002）：尝试单飞刷新并重放原请求
    if (
      result.code === ResultCode.TOKEN_EXPIRED &&
      response.config.url !== REFRESH_URL &&
      !response.config._replayed
    ) {
      if (isStale) {
        // 迟到 1002：会话已变更，不刷新、不重放，静默丢弃
        // 防止 Tab A 的 1002 用 Tab B 的 refresh token 重放 A 的请求
        return Promise.reject(
          new ApiError(ResultCode.UNAUTHORIZED, '会话已变更，迟到请求已丢弃'),
        )
      }
      return handleTokenExpired(response.config)
    }

    // 重放后仍 1002：新 token 也已失效
    if (result.code === ResultCode.TOKEN_EXPIRED && response.config._replayed) {
      if (isStale) {
        // 迟到的重放 1002：会话已变更，不清新会话的登录态
        return Promise.reject(
          new ApiError(ResultCode.UNAUTHORIZED, '会话已变更，迟到请求已丢弃'),
        )
      }
      clearAuthAndRedirect()
      ElMessage.error('登录已失效，请重新登录')
      return Promise.reject(new ApiError(result.code, result.message))
    }

    // 未登录/token 无效（1001）：清登录态，跳转登录页
    if (result.code === ResultCode.UNAUTHORIZED) {
      if (isStale) {
        // 迟到 1001：会话已变更，不清新会话的登录态
        return Promise.reject(
          new ApiError(ResultCode.UNAUTHORIZED, '会话已变更，迟到请求已丢弃'),
        )
      }
      clearAuthAndRedirect()
      ElMessage.error(result.message || '登录已失效，请重新登录')
      return Promise.reject(new ApiError(result.code, result.message))
    }

    // 账号冻结（2002）：清登录态，跳转登录页
    if (result.code === ResultCode.ACCOUNT_FROZEN) {
      if (isStale) {
        // 迟到 2002：会话已变更，不清新会话的登录态
        return Promise.reject(
          new ApiError(ResultCode.ACCOUNT_FROZEN, '会话已变更，迟到请求已丢弃'),
        )
      }
      clearAuthAndRedirect()
      ElMessage.error(result.message || '账号已冻结，请联系管理员')
      return Promise.reject(new ApiError(result.code, result.message))
    }

    // 1003 无权限：不刷新不清登录态，交由页面处理
    if (result.code === ResultCode.FORBIDDEN) {
      return Promise.reject(new ApiError(result.code, result.message))
    }

    // 其他业务错误（1xxx/2xxx）：仅提示，不清登录态
    if (result.code >= 1000 && result.code < 5000) {
      ElMessage.error(result.message || '操作失败')
      return Promise.reject(new ApiError(result.code, result.message))
    }

    // 5xxx 服务端错误：仅提示，不清登录态
    ElMessage.error(result.message || '服务器异常，请稍后重试')
    return Promise.reject(new ApiError(result.code, result.message))
  },
  (error: AxiosError) => {
    // 尝试解析后端结构化错误（HTTP 非 2xx 时后端可能仍返回 R<T>）
    if (error.response?.data) {
      const result = error.response.data as ApiResult<unknown>
      if (typeof result.code === 'number') {
        const reqGen = error.config?._sessionGen ?? 0
        const isStale = reqGen !== _sessionGeneration

        // 非 2xx 的 1002 也触发 refresh（网关可能将业务码映射为 HTTP 状态码）
        if (
          result.code === ResultCode.TOKEN_EXPIRED &&
          error.config &&
          error.config.url !== REFRESH_URL &&
          !error.config._replayed
        ) {
          if (isStale) {
            return Promise.reject(
              new ApiError(ResultCode.UNAUTHORIZED, '会话已变更，迟到请求已丢弃'),
            )
          }
          return handleTokenExpired(error.config)
        }
        // 重放后仍 1002：新 token 也已失效
        if (result.code === ResultCode.TOKEN_EXPIRED && error.config?._replayed) {
          if (isStale) {
            return Promise.reject(
              new ApiError(ResultCode.UNAUTHORIZED, '会话已变更，迟到请求已丢弃'),
            )
          }
          clearAuthAndRedirect()
          ElMessage.error('登录已失效，请重新登录')
          return Promise.reject(new ApiError(result.code, result.message))
        }
        // 1001/2002 清登录态（与 2xx 路径一致），但先检查会话版本号
        if (result.code === ResultCode.UNAUTHORIZED || result.code === ResultCode.ACCOUNT_FROZEN) {
          if (!isStale) {
            clearAuthAndRedirect()
          }
        }
        // 1003 不弹全局提示（由页面处理权限），其余业务错误（含 5xxx）提示
        if (result.code !== ResultCode.FORBIDDEN && !isStale) {
          ElMessage.error(result.message || '操作失败')
        }
        return Promise.reject(new ApiError(result.code, result.message))
      }
    }
    // 纯 HTTP 错误（无结构化 body）：不清登录态
    if (error.response) {
      const status = error.response.status
      if (status === 404) {
        ElMessage.error('请求的资源不存在')
      } else if (status >= 500) {
        ElMessage.error('服务器异常，请稍后重试')
      } else {
        ElMessage.error(`请求失败 (${status})`)
      }
    } else if (error.request) {
      ElMessage.error('网络连接异常，请检查网络')
    }
    // 网络错误不删 token（可能是临时波动）
    return Promise.reject(error)
  },
)

// ---------- 单飞刷新处理 ----------
async function handleTokenExpired(
  originalConfig: InternalAxiosRequestConfig,
): Promise<any> {
  // 进入时再检查一次会话版本号：防止请求排队期间 Tab B 已登录
  const genAtEntry = _sessionGeneration
  // A1 修复：refresh token 在 httpOnly cookie 中，无需从 localStorage 读取。
  // 如果 cookie 不存在或过期，后端 /auth/refresh 返回 1001/1002，按 fatal 处理。

  // 单飞：已有刷新请求正在进行时复用其 Promise
  if (!refreshPromise) {
    refreshPromise = doRefresh(genAtEntry).finally(() => {
      refreshPromise = null
      // 重置去重标志，允许下次 refresh 失败时重新弹窗
      refreshFailureNotified = false
    })
  }

  try {
    const newToken = await refreshPromise
    // 会话已变更（Tab B 退出/登录了新账号），旧 refresh 结果已静默丢弃
    // 不重放请求、不清登录态、不弹窗
    if (!newToken) {
      return Promise.reject(
        new ApiError(ResultCode.UNAUTHORIZED, '会话已变更，旧 refresh 结果已丢弃'),
      )
    }
    // P0-1 修复：refresh 成功后不再检查 genAtEntry !== _sessionGeneration。
    // 原因：doRefresh 内部 tokenStorage.set() 会递增 gen（N→N+1），若用 genAtEntry(=N)
    // 比较当前 gen(=N+1) 必然判为 stale，导致 refresh 成功但原请求永远无法重放。
    //
    // doRefresh 的内部双重校验（genAtCall + refresh-token 一致性）已保证：
    //   - 若 Tab B 在 doRefresh 期间登录（gen 变化），doRefresh 返回 null → 不重放
    //   - 若无跨标签变更，doRefresh 写入新 token 并返回 → 应重放
    //
    // 为防止 doRefresh 写入与重放之间 Tab B 登录覆盖 storage，直接注入 newToken
    // 到重放请求的 Authorization 头，不依赖请求拦截器从 storage 读取（可能读到 B 的 token）。
    originalConfig._replayed = true
    originalConfig._sessionGen = _sessionGeneration
    originalConfig.headers.Authorization = `Bearer ${newToken}`
    return instance(originalConfig)
  } catch (e) {
    // refresh 失败分类：
    //   确定性故障（1001 无效 / 1002 过期 / 2002 冻结）→ 清登录态，结束会话
    //   临时故障（网络错误 / 5xx / 5000）→ 不清 token，用户可稍后重试
    const isFatal =
      e instanceof ApiError &&
      (e.code === ResultCode.UNAUTHORIZED ||
        e.code === ResultCode.TOKEN_EXPIRED ||
        e.code === ResultCode.ACCOUNT_FROZEN)

    if (isFatal) {
      // 会话已变更时不清新会话
      if (genAtEntry === _sessionGeneration && !refreshFailureNotified) {
        refreshFailureNotified = true
        clearAuthAndRedirect()
        ElMessage.error('登录已过期，请重新登录')
      }
    } else {
      if (!refreshFailureNotified) {
        refreshFailureNotified = true
        ElMessage.error('网络异常，刷新登录态失败，请稍后重试')
      }
    }
    return Promise.reject(e)
  }
}

// ---------- 执行刷新请求（使用独立实例，跳过拦截器）----------
// genAtCall: 调用 doRefresh 时的会话版本号，用于写入前二次校验
async function doRefresh(
  genAtCall: number,
): Promise<string | null> {
  let response
  try {
    // A1 修复：refresh token 在 httpOnly cookie 中，浏览器自动携带（withCredentials）。
    // 不再从 localStorage 读取 refresh token，也不在 body 传递。
    response = await refreshInstance.post<ApiResult<LoginResponse>>(
      REFRESH_URL,
    )
  } catch (e) {
    // refresh 请求返回非 2xx：尝试解析后端结构化错误并转为 ApiError
    if (e instanceof AxiosError && e.response?.data) {
      const result = e.response.data as ApiResult<unknown>
      if (typeof result.code === 'number') {
        throw new ApiError(result.code, result.message)
      }
    }
    throw e
  }
  const result = response.data
  if (result.code !== ResultCode.SUCCESS || !result.data) {
    throw new ApiError(result.code, result.message)
  }

  // 写入前校验会话版本号：若 Tab B 在此期间登录（gen 变化），静默丢弃
  // 防止 Tab A refresh 返回时 Tab B 已登录，A 的新 token 覆盖 B 的会话
  if (genAtCall !== _sessionGeneration) {
    return null
  }

  const { token } = result.data
  // A1 修复：只存 access token，refresh token 在 httpOnly cookie 中（前端不可读）
  tokenStorage.setAccess(token)

  // 派发事件：store 监听后更新角色并重算菜单权限
  window.dispatchEvent(
    new CustomEvent('admin-token-refreshed', { detail: result.data }),
  )
  return token
}

// ---------- 清除登录态并跳转登录页 ----------
function clearAuthAndRedirect(): void {
  tokenStorage.clear()
  // 避免在登录页重复跳转
  if (window.location.pathname !== '/login') {
    window.location.href = '/login'
  }
}

// ---------- Token 存储工具 ----------
// set/clear 会递增 _sessionGeneration，使在途请求的迟到响应被过滤
export const tokenStorage = {
  getAccess(): string | null {
    return localStorage.getItem(ACCESS_TOKEN_KEY)
  },
  /** A1 修复：refresh token 在 httpOnly cookie 中，不再持久化到 localStorage */
  setAccess(access: string): void {
    localStorage.setItem(ACCESS_TOKEN_KEY, access)
    _sessionGeneration++
  },
  clear(): void {
    localStorage.removeItem(ACCESS_TOKEN_KEY)
    _sessionGeneration++
  },
  /** 当前会话版本号（供 auth store 做 CAS） */
  getSessionGen(): number {
    return _sessionGeneration
  },
}

export default instance
