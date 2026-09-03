/**
 * 管理端 UI 状态：侧边栏折叠 / 暗黑模式 / 多页签
 * 全部持久化到 localStorage，刷新后保持
 */
import { defineStore } from 'pinia'
import { computed, ref, watch } from 'vue'

const COLLAPSE_KEY = 'zhiyu_admin_sidebar_collapsed'
const DARK_KEY = 'zhiyu_admin_dark_mode'

export interface AdminTab {
  path: string
  title: string
}

export const useAppStore = defineStore('adminApp', () => {
  // ---------- 侧边栏折叠 ----------
  const sidebarCollapsed = ref(localStorage.getItem(COLLAPSE_KEY) === '1')
  function toggleSidebar(): void {
    sidebarCollapsed.value = !sidebarCollapsed.value
  }
  watch(sidebarCollapsed, (v) => {
    localStorage.setItem(COLLAPSE_KEY, v ? '1' : '0')
  })

  // ---------- 暗黑模式 ----------
  const darkMode = ref(localStorage.getItem(DARK_KEY) === '1')
  function toggleDark(): void {
    darkMode.value = !darkMode.value
  }
  // 同步到 <html> class，驱动 zy-*/adm-*/el-* 全部变量切换
  function applyDarkClass(): void {
    document.documentElement.classList.toggle('dark', darkMode.value)
  }
  applyDarkClass()
  watch(darkMode, applyDarkClass)

  // ---------- 多页签 ----------
  const tabs = ref<AdminTab[]>([])
  const activeTab = computed(() => tabs.value.find((t) => t.path === currentPath.value))

  /** 当前路由路径由 App 组件同步进来，避免 store 依赖 router 实例 */
  const currentPath = ref('/')

  function setCurrentPath(path: string): void {
    currentPath.value = path
  }

  /** 打开/激活页签； AFFIX（固定页签如驾驶舱）不可关闭 */
  function openTab(tab: AdminTab & { affix?: boolean }): void {
    const exists = tabs.value.find((t) => t.path === tab.path)
    if (exists) {
      if (tab.affix) exists.title = tab.title
      return
    }
    tabs.value.push({ path: tab.path, title: tab.title })
  }

  function closeTab(path: string): string | null {
    const idx = tabs.value.findIndex((t) => t.path === path)
    if (idx < 0) return null
    // affix 页签不允许关闭
    const closed = tabs.value[idx]
    if (!closed) return null
    tabs.value.splice(idx, 1)
    // 关闭的是当前页 → 返回相邻页签路径供路由跳转
    if (currentPath.value === path) {
      const next = tabs.value[idx - 1] ?? tabs.value[idx]
      return next?.path ?? null
    }
    return null
  }

  function closeOthers(path: string): void {
    tabs.value = tabs.value.filter((t) => t.path === path)
  }

  function closeAll(): string | null {
    tabs.value = []
    return '/'
  }

  return {
    sidebarCollapsed,
    toggleSidebar,
    darkMode,
    toggleDark,
    tabs,
    activeTab,
    currentPath,
    setCurrentPath,
    openTab,
    closeTab,
    closeOthers,
    closeAll,
  }
})
