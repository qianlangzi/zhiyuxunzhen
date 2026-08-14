/**
 * 管理端认证 Store（Pinia）
 *
 * 职责：
 *   - 管理 access/refresh token 持久化（通过 http.ts tokenStorage）
 *   - 管理 UserInfoVO（来自 /auth/me，主键字段是 id）
 *   - 提供角色驱动的菜单/路由权限
 *   - 监听 token 刷新事件，重算角色与菜单
 */

import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import * as authApi from '../api/auth'
import { tokenStorage } from '../api/http'
import {
  ADMIN_ROLES,
  ApiError,
  getAllowedMenus,
  getDefaultPath,
  type LoginRequest,
  type LoginResponse,
  type NavItem,
  ResultCode,
  type UserInfoVO,
} from '../types'

export const useAuthStore = defineStore('admin-auth', () => {
  // ---------- State ----------
  const user = ref<UserInfoVO | null>(null)
  const role = ref<number | null>(null)
  /** 是否需要强制修改密码（批量导入学生首次登录时为 true） */
  const mustChangePassword = ref(false)

  // ---------- Getters ----------
  const isAuthenticated = computed(
    () => !!tokenStorage.getAccess() && !!user.value,
  )

  const allowedMenus = computed<NavItem[]>(() => {
    if (role.value === null) return []
    return getAllowedMenus(role.value)
  })

  const realName = computed(() => user.value?.realName ?? user.value?.username ?? '')

  // ---------- Actions ----------

  /** 登录：保存 token → 拉取用户信息 → 返回默认落地路径 */
  async function login(req: LoginRequest): Promise<string> {
    const resp: LoginResponse = await authApi.login(req)
    tokenStorage.setAccess(resp.token)

    // 拉取完整用户信息（/auth/me 返回 UserInfoVO，含 id/status 等）
    const userInfo = await authApi.me()
    user.value = userInfo
    role.value = userInfo.role
    mustChangePassword.value = !!userInfo.mustChangePassword

    return getDefaultPath(userInfo.role)
  }

  /** 登出：通知后端 → 清除本地状态 → 跳转登录页 */
  async function logout(): Promise<void> {
    await authApi.logout()
    resetState()
    // 跳转登录页（避免在登录页重复跳转）
    if (window.location.pathname !== '/login') {
      window.location.href = '/login'
    }
  }

  /** 应用启动时恢复会话：token 存在则拉取用户信息 */
  async function restore(): Promise<boolean> {
    const access = tokenStorage.getAccess()
    if (!access) return false

    try {
      const userInfo = await authApi.me()
      user.value = userInfo
      role.value = userInfo.role
      mustChangePassword.value = !!userInfo.mustChangePassword
      return true
    } catch {
      // 不清除 token，仅清内存用户状态：
      //   - 认证失败（1001/2002）时 http.ts 已清 token 并跳转登录页
      //   - 网络错误或 5xx 时保留 token，用户下次请求或刷新可重试
      // 避免临时网络波动导致用户被误踢出登录
      user.value = null
      role.value = null
      mustChangePassword.value = false
      return false
    }
  }

  /** 修改密码：调用后端 → 替换新 token → 清除强制改密标志
   *
   *  后端改密后签发新 token（携带递增后的 credentialVersion），
   *  必须替换旧 token，否则旧 token 因版本不匹配被后端拒绝（1001）。
   *
   *  P0 复审修复：gen CAS 防止迟到改密响应覆盖新登录。
   *  场景：Tab A 改密 → Tab B 登录（gen++）→ Tab A 改密响应迟到 →
   *    若无条件 set，会把 A 的新 token 写入 localStorage，覆盖 B 的会话。
   *  防护：请求前快照 gen，响应后比较——若 gen 已变，丢弃迟到响应。
   */
  async function changePassword(oldPassword: string, newPassword: string): Promise<void> {
    const genAtRequest = tokenStorage.getSessionGen()
    const resp: LoginResponse = await authApi.changePassword(oldPassword, newPassword)

    // gen CAS：若期间发生了 login/logout（gen 变化），丢弃迟到响应
    if (genAtRequest !== tokenStorage.getSessionGen()) {
      // 会话已变更（Tab B 登录/登出），A 的改密响应迟到，不覆盖新会话
      throw new ApiError(
        ResultCode.UNAUTHORIZED,
        '会话已变更，改密响应已丢弃，请重新登录后修改密码',
      )
    }

    // 替换新 token（携带递增后的 credentialVersion，旧 token 立即失效）
    // tokenStorage.set 内部会递增 gen，使在途请求的迟到响应被过滤
    tokenStorage.setAccess(resp.token)
    mustChangePassword.value = false
    if (user.value) {
      user.value = { ...user.value, mustChangePassword: false }
    }
  }

  /** token 刷新成功后更新角色（由 http.ts 事件触发） */
  function handleTokenRefreshed(resp: LoginResponse): void {
    if (resp.role !== role.value) {
      role.value = resp.role
      // 角色变更后需要重新拉取完整用户信息
      authApi.me().then((userInfo) => {
        user.value = userInfo
        mustChangePassword.value = !!userInfo.mustChangePassword
      }).catch(() => {
        // 拉取失败不阻塞，下次请求会重试
      })
    }
  }

  /** 重置状态 */
  function resetState(): void {
    user.value = null
    role.value = null
    mustChangePassword.value = false
    tokenStorage.clear()
  }

  return {
    user,
    role,
    mustChangePassword,
    isAuthenticated,
    allowedMenus,
    realName,
    login,
    logout,
    restore,
    changePassword,
    handleTokenRefreshed,
    resetState,
  }
})
