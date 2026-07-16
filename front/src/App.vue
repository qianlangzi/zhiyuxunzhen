<script setup lang="ts">
import { computed, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useUserStore } from '@/stores/user'
import brandLogo from '@/assets/brand-logo.png'

type NavItem = {
  label: string
  path: string
  icon: string
  secondary?: boolean
}

const route = useRoute()
const router = useRouter()
const user = useUserStore()
const sidebarCollapsed = ref(false)

const isLoginPage = computed(() => route.path === '/login')
const isTeacher = computed(() => user.role === 1)
const roleName = computed(() => (isTeacher.value ? '教师端' : '学生端'))
const displayName = computed(() => user.username || (isTeacher.value ? 'teacher01' : 'student01'))

const teacherNav: NavItem[] = [
  { label: '教学概览', path: '/', icon: 'House' },
  { label: '模拟病人配置', path: '/teacher/cases', icon: 'EditPen' },
  { label: '病例广场', path: '/teacher/market', icon: 'Grid' },
  { label: '作业分发', path: '/teacher/assignments', icon: 'Calendar' },
  { label: '批阅复核', path: '/teacher/review', icon: 'DocumentChecked' },
  { label: '班级常错点', path: '/teacher/insights', icon: 'TrendCharts' },
  { label: '个人资料', path: '/profile', icon: 'User', secondary: true }
]

const studentNav: NavItem[] = [
  { label: '今日训练', path: '/', icon: 'House' },
  { label: '每日一例', path: '/student/daily', icon: 'Calendar' },
  { label: '选择病例', path: '/student/cases', icon: 'FirstAidKit' },
  { label: '问诊室', path: '/student/chat', icon: 'ChatDotRound' },
  { label: '能力反馈', path: '/student/feedback', icon: 'DataAnalysis' },
  { label: '错题复盘', path: '/student/mistakes', icon: 'Notebook', secondary: true },
  { label: '影像判读', path: '/student/image', icon: 'Picture', secondary: true },
  { label: '大病历提交', path: '/student/record', icon: 'Document', secondary: true },
  { label: '个人资料', path: '/profile', icon: 'User', secondary: true }
]

const navItems = computed(() => (isTeacher.value ? teacherNav : studentNav))

function logout() {
  user.logout()
  router.push('/login')
}
</script>

<template>
  <router-view v-if="isLoginPage" />

  <div v-else class="app-frame" :class="{ collapsed: sidebarCollapsed }">
    <aside class="sidebar" aria-label="主导航">
      <div class="brand-row">
        <button class="brand-mark zy-button" type="button" aria-label="返回首页" @click="router.push('/')">
          <img :src="brandLogo" alt="" />
        </button>
        <div class="brand-copy">
          <strong>知语寻真</strong>
          <span>{{ roleName }}</span>
        </div>
      </div>

      <nav class="nav-list">
        <router-link
          v-for="item in navItems"
          :key="item.path"
          class="nav-item"
          :class="{ secondary: item.secondary }"
          :to="item.path"
          :aria-label="item.label"
          :data-label="item.label"
          :title="sidebarCollapsed ? item.label : undefined"
        >
          <el-icon><component :is="item.icon" /></el-icon>
          <span>{{ item.label }}</span>
        </router-link>
      </nav>

      <div class="sidebar-footer">
        <button
          class="collapse-button zy-button"
          type="button"
          :aria-label="sidebarCollapsed ? '展开侧边栏' : '收起侧边栏'"
          :aria-expanded="!sidebarCollapsed"
          @click="sidebarCollapsed = !sidebarCollapsed"
        >
          <el-icon><Fold v-if="!sidebarCollapsed" /><Expand v-else /></el-icon>
          <span>{{ sidebarCollapsed ? '展开' : '收起' }}</span>
        </button>
      </div>
    </aside>

    <section class="app-content">
      <header class="topbar">
        <router-link class="profile-link" to="/profile" aria-label="查看个人资料">
          <strong>{{ displayName }}</strong>
          <span>{{ roleName }}</span>
        </router-link>
        <el-button plain @click="logout">退出登录</el-button>
      </header>

      <router-view v-slot="{ Component }">
        <transition name="page-fade" mode="out-in">
          <component :is="Component" :key="route.fullPath" />
        </transition>
      </router-view>
    </section>
  </div>
</template>

<style scoped>
.app-frame {
  display: grid;
  grid-template-columns: 260px minmax(0, 1fr);
  min-height: 100dvh;
}

.app-frame.collapsed {
  grid-template-columns: 84px minmax(0, 1fr);
}

.sidebar {
  position: sticky;
  top: 0;
  display: flex;
  flex-direction: column;
  height: 100dvh;
  padding: 18px 14px;
  border-right: 1px solid var(--zy-line);
  background: rgba(255, 255, 255, 0.94);
}

.brand-row {
  display: flex;
  align-items: center;
  gap: 12px;
  min-height: 52px;
  padding: 4px 4px 16px;
}

.brand-mark {
  display: grid;
  flex: 0 0 auto;
  place-items: center;
  width: 44px;
  height: 44px;
  overflow: hidden;
  border: 1px solid var(--zy-line);
  border-radius: 14px;
  background: #fff;
}

.brand-mark img {
  width: 100%;
  height: 100%;
  object-fit: contain;
}

.brand-copy,
.nav-item span,
.collapse-button span {
  overflow: hidden;
  white-space: nowrap;
  transition: opacity 160ms ease-out, transform 160ms ease-out;
}

.brand-copy strong,
.brand-copy span,
.topbar strong,
.topbar span {
  display: block;
}

.brand-copy strong {
  color: var(--zy-ink);
  line-height: 1.2;
}

.brand-copy span,
.topbar span {
  color: var(--zy-muted);
  font-size: 12px;
  font-weight: 800;
}

.nav-list {
  display: grid;
  gap: 7px;
  margin-top: 10px;
}

.nav-item,
.collapse-button {
  position: relative;
  display: flex;
  align-items: center;
  gap: 12px;
  min-height: 46px;
  padding: 0 12px;
  border-radius: 16px;
  color: var(--zy-muted);
  font-size: 14px;
  font-weight: 800;
  text-decoration: none;
}

.nav-item .el-icon,
.collapse-button .el-icon {
  flex: 0 0 auto;
  font-size: 18px;
}

.nav-item:hover,
.nav-item.router-link-active {
  color: var(--zy-brand-strong);
  background: var(--zy-brand-soft);
}

.sidebar-footer {
  margin-top: auto;
  padding-top: 16px;
}

.collapse-button {
  width: 100%;
  border: 0;
  background: rgba(15, 76, 92, 0.07);
  cursor: pointer;
}

.collapsed .brand-copy,
.collapsed .nav-item span,
.collapsed .collapse-button span {
  display: none;
  opacity: 0;
}

.collapsed .nav-item,
.collapsed .collapse-button {
  justify-content: center;
  padding: 0;
}

.collapsed .nav-item:focus-visible::after,
.collapsed .nav-item:hover::after {
  position: absolute;
  left: calc(100% + 10px);
  top: 50%;
  z-index: 2;
  min-width: max-content;
  padding: 8px 10px;
  border: 1px solid var(--zy-line);
  border-radius: 12px;
  background: #fff;
  color: var(--zy-ink);
  box-shadow: var(--zy-shadow-soft);
  content: attr(data-label);
  font-size: 13px;
  line-height: 1;
  transform: translateY(-50%);
}

.app-content {
  min-width: 0;
  padding: 18px 24px 32px;
}

.topbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  min-height: 56px;
  margin-bottom: 22px;
}

.topbar strong {
  color: var(--zy-ink);
}

.profile-link {
  color: inherit;
  text-decoration: none;
}

.profile-link:hover strong,
.profile-link:focus-visible strong {
  color: var(--zy-brand-strong);
}

.page-fade-enter-active,
.page-fade-leave-active {
  transition: opacity 180ms ease-out, transform 180ms ease-out;
}

.page-fade-enter-from {
  opacity: 0;
  transform: translateY(8px);
}

.page-fade-leave-to {
  opacity: 0;
  transform: translateY(-6px);
}

@media (max-width: 820px) {
  .app-frame,
  .app-frame.collapsed {
    grid-template-columns: 1fr;
  }

  .sidebar {
    position: sticky;
    z-index: var(--zy-z-sticky);
    height: auto;
    padding: 10px 12px;
    border-right: 0;
    border-bottom: 1px solid var(--zy-line);
  }

  .brand-row,
  .sidebar-footer {
    display: none;
  }

  .nav-list {
    display: grid;
    grid-template-columns: repeat(4, minmax(0, 1fr));
    gap: 8px;
    margin-top: 0;
  }

  .nav-item.secondary {
    display: none;
  }

  .nav-item {
    justify-content: center;
    min-width: 0;
    min-height: 46px;
    padding: 0 8px;
    gap: 6px;
    font-size: 12px;
  }

  .nav-item span {
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .app-content {
    padding: 14px 14px 28px;
  }
}

@media (max-width: 520px) {
  .nav-list {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }
}
</style>
