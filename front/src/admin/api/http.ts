/**
 * 管理端 HTTP 客户端（axios 实例 + 拦截器）
 *
 * 核心规则（P0-C 鉴权链路）：
 *   1. 普通请求的 code=1002 触发刷新（2xx 和非 2xx 路径均覆盖）；1001/1003 不刷新
 *   2. refresh 请求自身跳过拦截，原请求最多重放一次
 *   3. refresh 失败的确定性故障（1001/1002/2002）才清登录态；
 *      网络错误或 5xx/5000 不清 token（可能是临时故障）
 *   4. refresh 请求的非 2xx 响应也解析结构化 code，统一转 ApiError
 *   5. 并发 refresh 失败只弹一次提示（refreshFailureNotified 去重）
 *   6. 刷新成功后派发事件，store 据此重算角色与菜单权限
 *   7. 写入新 token 前校验 refresh token 仍与发起时一致，防止在途旧 refresh
 *      覆盖新会话（Tab A refresh 期间 Tab B 退出/登录了新账号）
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
const REFRESH_TOKEN_KEY = 'zhiyu_admin_refresh_token'

/** 刷新 token 的 API 路径 */
const REFRESH_URL = '/api/v1/auth/refresh'

// ---------- 单飞刷新状态 ----------
// doRefresh 返回 null 表示会话已变更（在途旧 refresh 被静默丢弃）
let refreshPromise: Promise<string | null> | null = null
// 并发 refresh 失败时去重弹窗：多个请求复用同一 refreshPromise，失败只弹一次
let refreshFailureNotified = false

// ---------- 主实例（带拦截器）----------
const instance: AxiosInstance = axios.create({
  timeout: 15000,
})

// ---------- 刷新专用实例（无拦截器，避免递归）----------
const refreshInstance: AxiosInstance = axios.create({
  timeout: 15000,
})

// ---------- 请求拦截：注入 Authorization ----------
instance.interceptors.request.use((config: InternalAxiosRequestConfig) => {
  const token = tokenStorage.getAccess()
  // refresh 请求不注入 access token（避免携带过期 token 干扰）
  if (token && config.url !== REFRESH_URL) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

// ---------- 扩展 config 类型：标记已重放 ----------
declare module 'axios' {
  interface InternalAxiosRequestConfig {
    _replayed?: boolean
  }
}

// ---------- 响应拦截：统一错误处理 ----------
instance.interceptors.response.use(
  (response) => {
    const result = response.data as ApiResult<unknown>

    // 业务成功
    if (result.code === ResultCode.SUCCESS) {
      return response
    }

    // token 过期（1002）：尝试单飞刷新并重放原请求
    if (
      result.code === ResultCode.TOKEN_EXPIRED &&
      response.config.url !== REFRESH_URL &&
      !response.config._replayed
    ) {
      return handleTokenExpired(response.config)
    }

    // 重放后仍 1002：新 token 也已失效，结束会话
    if (result.code === ResultCode.TOKEN_EXPIRED && response.config._replayed) {
      clearAuthAndRedirect()
      ElMessage.error('登录已失效，请重新登录')
      return Promise.reject(new ApiError(result.code, result.message))
    }

    // 未登录/token 无效（1001）：清登录态，跳转登录页
    if (result.code === ResultCode.UNAUTHORIZED) {
      clearAuthAndRedirect()
      ElMessage.error(result.message || '登录已失效，请重新登录')
      return Promise.reject(new ApiError(result.code, result.message))
    }

    // 账号冻结（2002）：清登录态，跳转登录页
    if (result.code === ResultCode.ACCOUNT_FROZEN) {
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
        // 非 2xx 的 1002 也触发 refresh（网关可能将业务码映射为 HTTP 状态码）
        if (
          result.code === ResultCode.TOKEN_EXPIRED &&
          error.config &&
          error.config.url !== REFRESH_URL &&
          !error.config._replayed
        ) {
          return handleTokenExpired(error.config)
        }
        // 重放后仍 1002：新 token 也已失效，结束会话
        if (result.code === ResultCode.TOKEN_EXPIRED && error.config?._replayed) {
          clearAuthAndRedirect()
          ElMessage.error('登录已失效，请重新登录')
          return Promise.reject(new ApiError(result.code, result.message))
        }
        // 1001/2002 清登录态（与 2xx 路径一致）
        if (result.code === ResultCode.UNAUTHORIZED || result.code === ResultCode.ACCOUNT_FROZEN) {
          clearAuthAndRedirect()
        }
        // 1003 不弹全局提示（由页面处理权限），其余业务错误（含 5xxx）提示
        if (result.code !== ResultCode.FORBIDDEN) {
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
  const refreshToken = tokenStorage.getRefresh()
  if (!refreshToken) {
    // 无 refresh token：确定性失败，清登录态（并发时只弹一次）
    if (!refreshFailureNotified) {
      refreshFailureNotified = true
      clearAuthAndRedirect()
      ElMessage.error('登录已过期，请重新登录')
    }
    return Promise.reject(
      new ApiError(ResultCode.UNAUTHORIZED, '无 refresh token'),
    )
  }

  // 单飞：已有刷新请求在进行时复用其 Promise
  if (!refreshPromise) {
    refreshPromise = doRefresh(refreshToken).finally(() => {
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
    // 刷新成功，标记并重放原请求（最多一次）
    originalConfig._replayed = true
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
      if (!refreshFailureNotified) {
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
async function doRefresh(refreshToken: string): Promise<string | null> {
  let response
  try {
    response = await refreshInstance.post<ApiResult<LoginResponse>>(
      REFRESH_URL,
      { refreshToken },
    )
  } catch (e) {
    // refresh 请求返回非 2xx：尝试解析后端结构化错误并转为 ApiError
    // 后端 refresh token 过期返回 code=1002，必须转为 ApiError 才能被
    // handleTokenExpired 的 catch 正确分类为确定性故障
    if (e instanceof AxiosError && e.response?.data) {
      const result = e.response.data as ApiResult<unknown>
      if (typeof result.code === 'number') {
        throw new ApiError(result.code, result.message)
      }
    }
    // 纯网络错误（无响应）：重新抛出，handleTokenExpired 按"临时故障"处理
    throw e
  }
  const result = response.data
  if (result.code !== ResultCode.SUCCESS || !result.data) {
    throw new ApiError(result.code, result.message)
  }

  // 写入前校验：当前会话的 refresh token 仍与发起刷新时一致
  // 防止在途旧 refresh 覆盖新会话：
  //   Tab A 发起 refresh → Tab B 退出或登录用户 B →
  //   Tab A 的旧 refresh 返回，若不校验会把用户 A 的 token 写回共享 localStorage
  // 失配时静默丢弃：不写 token、不派事件、不重放请求
  if (tokenStorage.getRefresh() !== refreshToken) {
    return null
  }

  const { token, refreshToken: newRefreshToken } = result.data
  tokenStorage.set(token, newRefreshToken)

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
export const tokenStorage = {
  getAccess(): string | null {
    return localStorage.getItem(ACCESS_TOKEN_KEY)
  },
  getRefresh(): string | null {
    return localStorage.getItem(REFRESH_TOKEN_KEY)
  },
  set(access: string, refresh: string): void {
    localStorage.setItem(ACCESS_TOKEN_KEY, access)
    localStorage.setItem(REFRESH_TOKEN_KEY, refresh)
  },
  clear(): void {
    localStorage.removeItem(ACCESS_TOKEN_KEY)
    localStorage.removeItem(REFRESH_TOKEN_KEY)
  },
}

export default instance
