<script setup lang="ts">
import { computed, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessageBox } from 'element-plus'
import { useAuthStore } from './stores/auth'
import { useAppStore } from './stores/app'
import type { NavItem } from './types'
import ChangePasswordDialog from './components/ChangePasswordDialog.vue'
import brandLogo from '@/assets/brand-logo.png'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const appStore = useAppStore()

// 登录页不渲染管理端布局（侧栏/顶栏），Login.vue 自带全屏布局
const isLoginPage = computed(() => route.path === '/login')

// ---------- 菜单 ----------
/** 一级菜单 + 展开的二级（authStore.allowedMenus 已按 role 递归过滤） */
const menus = computed(() => authStore.allowedMenus)

/** 折叠时默认展开的一级（无子菜单的项高亮用） */
const activeMenuPath = computed(() => route.path)

/** 当前页所属菜单链（面包屑用）：[一级, 二级?] */
const breadcrumb = computed<NavItem[]>(() => {
  const chain: NavItem[] = []
  for (const item of menus.value) {
    if (route.path === item.path) {
      chain.push(item)
      break
    }
    const child = item.children?.find(
      (c) => route.path === c.path || route.path.startsWith(c.path + '/'),
    )
    if (child) {
      chain.push(item, child)
      break
    }
    if (route.path.startsWith(item.path + '/') && !item.children?.length) {
      chain.push(item)
      break
    }
  }
  return chain
})

function findMenuLabel(path: string): string {
  for (const item of menus.value) {
    if (item.path === path) return item.label
    const child = item.children?.find((c) => c.path === path)
    if (child) return child.label
  }
  return path
}

// ---------- 多页签 ----------
// 路由变化 → 同步页签；affix 页签（驾驶舱）不可关闭
watch(
  () => route.path,
  (path) => {
    appStore.setCurrentPath(path)
    if (isLoginPage.value) return
    const affix = menus.value.some((m) => m.path === path && m.affix)
    appStore.openTab({ path, title: findMenuLabel(path), affix })
  },
  { immediate: true },
)

function onTabClick(path: string): void {
  if (path !== route.path) router.push(path)
}

function onTabClose(path: string): void {
  const next = appStore.closeTab(path)
  if (next) router.push(next)
}

function refreshTab(): void {
  // 通过重新导航触发组件重建（key=fullPath 已在 router-view 绑定）
  const { path, query } = route
  router.replace({ path: '/redirect' + path, query })
}

// ---------- 顶栏动作 ----------
async function handleLogout(): Promise<void> {
  try {
    await ElMessageBox.confirm('确定退出管理端？', '提示', {
      confirmButtonText: '退出',
      cancelButtonText: '取消',
      type: 'warning',
    })
    await authStore.logout()
  } catch {
    // 用户取消
  }
}

async function toggleFullscreen(): Promise<void> {
  if (document.fullscreenElement) {
    await document.exitFullscreen()
  } else {
    await document.documentElement.requestFullscreen()
  }
}
</script>

<template>
  <!-- 登录页：独立全屏布局，不渲染侧栏/顶栏 -->
  <router-view v-if="isLoginPage" />

  <!-- 管理端主布局：侧边栏 + 顶栏 + 页签栏 + 内容区 -->
  <div v-else class="adm-frame">
    <!-- ============ 侧边栏 ============ -->
    <aside
      class="adm-sidebar"
      :class="{ collapsed: appStore.sidebarCollapsed }"
      aria-label="管理端导航"
    >
      <div class="adm-brand">
        <img :src="brandLogo" alt="智愈寻真" />
        <div v-show="!appStore.sidebarCollapsed" class="adm-brand-text">
          <strong>知语寻真</strong>
          <span>管理控制台</span>
        </div>
      </div>

      <el-scrollbar class="adm-menu-scroll">
        <el-menu
          :default-active="activeMenuPath"
          :collapse="appStore.sidebarCollapsed"
          :collapse-transition="false"
          router
          class="adm-menu"
        >
          <template v-for="item in menus" :key="item.path">
            <!-- 有二级菜单：折叠分组 -->
            <el-sub-menu v-if="item.children?.length" :index="item.path">
              <template #title>
                <el-icon><component :is="item.icon" /></el-icon>
                <span>{{ item.label }}</span>
              </template>
              <el-menu-item
                v-for="child in item.children"
                :key="child.path"
                :index="child.path"
              >
                <el-icon><component :is="child.icon" /></el-icon>
                <span>{{ child.label }}</span>
              </el-menu-item>
            </el-sub-menu>

            <!-- 无二级：平铺 -->
            <el-menu-item v-else :index="item.path">
              <el-icon><component :is="item.icon" /></el-icon>
              <template #title>{{ item.label }}</template>
            </el-menu-item>
          </template>
        </el-menu>
      </el-scrollbar>

      <button
        class="adm-collapse-btn"
        :title="appStore.sidebarCollapsed ? '展开侧边栏' : '收起侧边栏'"
        @click="appStore.toggleSidebar()"
      >
        <el-icon :size="16">
          <component :is="appStore.sidebarCollapsed ? 'Expand' : 'Fold'" />
        </el-icon>
      </button>
    </aside>

    <!-- ============ 右侧主区 ============ -->
    <section class="adm-main">
      <!-- 顶栏 -->
      <header class="adm-topbar">
        <div class="topbar-left">
          <el-breadcrumb separator="/" class="adm-breadcrumb">
            <el-breadcrumb-item
              v-for="(crumb, i) in breadcrumb"
              :key="crumb.path + i"
              :to="i < breadcrumb.length - 1 ? crumb.path : undefined"
            >
              {{ crumb.label }}
            </el-breadcrumb-item>
          </el-breadcrumb>
        </div>

        <div class="topbar-right">
          <button class="topbar-icon-btn" title="暗色/浅色切换" @click="appStore.toggleDark()">
            <el-icon :size="16">
              <component :is="appStore.darkMode ? 'Sunny' : 'Moon'" />
            </el-icon>
          </button>
          <button class="topbar-icon-btn" title="全屏" @click="toggleFullscreen">
            <el-icon :size="16"><FullScreen /></el-icon>
          </button>

          <el-dropdown trigger="click">
            <div class="topbar-user">
              <span class="user-avatar">{{ (authStore.realName || '管').slice(0, 1) }}</span>
              <span class="user-name">{{ authStore.realName }}</span>
              <el-icon :size="12" class="user-arrow"><ArrowDown /></el-icon>
            </div>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item disabled>
                  {{ authStore.role === 4 ? '超级管理员' : '已登录' }}
                </el-dropdown-item>
                <el-dropdown-item divided @click="handleLogout">退出管理端</el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </header>

      <!-- 页签栏 -->
      <div v-if="appStore.tabs.length" class="adm-tagsbar">
        <el-scrollbar>
          <div class="tags-inner">
            <div
              v-for="tab in appStore.tabs"
              :key="tab.path"
              class="adm-tag"
              :class="{ active: tab.path === route.path }"
              @click="onTabClick(tab.path)"
            >
              <span>{{ tab.title }}</span>
              <el-icon
                v-if="tab.path !== '/'"
                class="tag-close"
                @click.stop="onTabClose(tab.path)"
              >
                <Close />
              </el-icon>
            </div>
          </div>
        </el-scrollbar>
      </div>

      <!-- 内容区 -->
      <main class="adm-content">
        <router-view v-slot="{ Component }">
          <transition name="page-fade" mode="out-in">
            <component :is="Component" :key="route.fullPath" />
          </transition>
        </router-view>
      </main>
    </section>

    <!-- 强制改密对话框：mustChangePassword=true 时模态展示 -->
    <ChangePasswordDialog />
  </div>
</template>

<style scoped>
.adm-frame {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr);
  min-height: 100dvh;
  background: var(--adm-content-bg);
}

/* ================= 侧边栏 ================= */
.adm-sidebar {
  position: sticky;
  top: 0;
  display: flex;
  flex-direction: column;
  width: var(--adm-sidebar-width);
  height: 100dvh;
  background: linear-gradient(180deg, var(--adm-sidebar-bg), var(--adm-sidebar-bg-deep));
  transition: width 0.22s ease;
}

.adm-sidebar.collapsed {
  width: var(--adm-sidebar-collapsed-width);
}

.adm-brand {
  display: flex;
  align-items: center;
  gap: 10px;
  min-height: 60px;
  padding: 0 14px;
  border-bottom: 1px solid var(--adm-sidebar-line);
  overflow: hidden;
  white-space: nowrap;
}

.adm-brand img {
  flex: none;
  width: 34px;
  height: 34px;
  border-radius: 9px;
  object-fit: contain;
}

.adm-brand-text strong {
  display: block;
  color: var(--adm-sidebar-ink);
  font-size: 15px;
  line-height: 1.25;
}

.adm-brand-text span {
  display: block;
  color: var(--adm-sidebar-muted);
  font-size: 11px;
  letter-spacing: 0.04em;
}

.adm-menu-scroll {
  flex: 1;
  min-height: 0;
}

.adm-menu {
  border-right: 0;
  background: transparent;
}

/* el-menu 深色主题覆盖 */
.adm-menu :deep(.el-menu-item),
.adm-menu :deep(.el-sub-menu__title) {
  height: 44px;
  margin: 2px 8px;
  border-radius: 8px;
  color: var(--adm-sidebar-muted);
  font-size: 13.5px;
  transition: background 0.15s ease, color 0.15s ease;
}

.adm-menu :deep(.el-menu-item:hover),
.adm-menu :deep(.el-sub-menu__title:hover) {
  background: var(--adm-sidebar-hover);
  color: var(--adm-sidebar-ink);
}

.adm-menu :deep(.el-menu-item.is-active) {
  background: var(--adm-sidebar-active);
  color: var(--adm-sidebar-active-ink);
  font-weight: 600;
}

.adm-menu :deep(.el-sub-menu.is-active > .el-sub-menu__title) {
  color: var(--adm-sidebar-ink);
}

.adm-menu :deep(.el-menu.el-menu--inline .el-menu-item) {
  padding-left: 44px !important;
  font-size: 13px;
}

.adm-menu.el-menu--collapse :deep(.el-menu-item),
.adm-menu.el-menu--collapse :deep(.el-sub-menu__title) {
  margin: 2px 10px;
  padding: 0 16px;
}

.adm-collapse-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 42px;
  border: 0;
  border-top: 1px solid var(--adm-sidebar-line);
  background: transparent;
  color: var(--adm-sidebar-muted);
  cursor: pointer;
  transition: color 0.15s ease, background 0.15s ease;
}

.adm-collapse-btn:hover {
  background: var(--adm-sidebar-hover);
  color: var(--adm-sidebar-ink);
}

/* ================= 顶栏 ================= */
.adm-main {
  display: flex;
  flex-direction: column;
  min-width: 0;
}

.adm-topbar {
  position: sticky;
  top: 0;
  z-index: var(--zy-z-sticky);
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  height: var(--adm-topbar-height);
  padding: 0 20px;
  border-bottom: 1px solid var(--adm-card-line);
  background: var(--adm-card-bg);
}

.topbar-left {
  display: flex;
  align-items: center;
  min-width: 0;
}

.adm-breadcrumb {
  white-space: nowrap;
}

.topbar-right {
  display: flex;
  align-items: center;
  gap: 6px;
}

.topbar-icon-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 34px;
  height: 34px;
  border: 0;
  border-radius: 8px;
  background: transparent;
  color: var(--zy-muted);
  cursor: pointer;
  transition: background 0.15s ease, color 0.15s ease;
}

.topbar-icon-btn:hover {
  background: var(--zy-brand-soft);
  color: var(--zy-brand-strong);
}

.topbar-user {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-left: 8px;
  padding: 4px 10px 4px 4px;
  border-radius: 99px;
  cursor: pointer;
  transition: background 0.15s ease;
}

.topbar-user:hover {
  background: var(--zy-brand-soft);
}

.user-avatar {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 30px;
  height: 30px;
  border-radius: 50%;
  background: var(--zy-brand);
  color: #fff;
  font-size: 13px;
  font-weight: 600;
}

.user-name {
  color: var(--zy-ink);
  font-size: 13.5px;
  font-weight: 600;
  max-width: 9em;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.user-arrow {
  color: var(--zy-muted);
}

/* ================= 页签栏 ================= */
.adm-tagsbar {
  position: sticky;
  top: var(--adm-topbar-height);
  z-index: calc(var(--zy-z-sticky) - 1);
  border-bottom: 1px solid var(--adm-card-line);
  background: var(--adm-card-bg);
}

.tags-inner {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 16px;
  width: max-content;
}

.adm-tag {
  display: flex;
  align-items: center;
  gap: 6px;
  height: 26px;
  padding: 0 10px;
  border: 1px solid var(--adm-card-line);
  border-radius: 6px;
  color: var(--zy-muted);
  font-size: 12.5px;
  cursor: pointer;
  user-select: none;
  transition: all 0.15s ease;
  white-space: nowrap;
}

.adm-tag:hover {
  color: var(--zy-brand-strong);
  border-color: var(--zy-brand-soft);
}

.adm-tag.active {
  background: var(--zy-brand);
  border-color: var(--zy-brand);
  color: #fff;
}

.tag-close {
  border-radius: 50%;
  font-size: 11px;
  transition: background 0.15s ease;
}

.tag-close:hover {
  background: rgba(0, 0, 0, 0.18);
}

/* ================= 内容区 ================= */
.adm-content {
  flex: 1;
  min-width: 0;
  padding: 18px 20px 32px;
}

@media (max-width: 860px) {
  .adm-sidebar {
    position: fixed;
    z-index: calc(var(--zy-z-sticky) + 2);
    box-shadow: var(--zy-shadow);
  }

  .adm-sidebar.collapsed {
    width: 0;
  }

  .adm-frame {
    grid-template-columns: minmax(0, 1fr);
  }

  .adm-content {
    padding: 14px 12px 28px;
  }
}
</style>
