<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { ElMessageBox } from 'element-plus'
import { useAuthStore } from './stores/auth'
import ChangePasswordDialog from './components/ChangePasswordDialog.vue'
import brandLogo from '@/assets/brand-logo.png'

const route = useRoute()
const authStore = useAuthStore()

// 登录页不渲染管理端布局（侧栏/顶栏），Login.vue 自带全屏布局
const isLoginPage = computed(() => route.path === '/login')

// 菜单由角色驱动（allowedMenus 已按 role 过滤）
const activeTitle = computed(() => {
  const item = authStore.allowedMenus.find((m) => m.path === route.path)
  if (item) return item.label
  if (route.path === '/no-access') return '暂无可用功能'
  return '管理控制台'
})

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
</script>

<template>
  <!-- 登录页：独立全屏布局，不渲染侧栏/顶栏 -->
  <router-view v-if="isLoginPage" />

  <!-- 管理端主布局 -->
  <div v-else class="admin-frame">
    <aside class="admin-sidebar" aria-label="管理端导航">
      <div class="admin-brand">
        <img :src="brandLogo" alt="" />
        <div>
          <strong>知语寻真</strong>
          <span>管理控制台</span>
        </div>
      </div>

      <nav class="admin-nav">
        <router-link
          v-for="item in authStore.allowedMenus"
          :key="item.path"
          :to="item.path"
          class="admin-nav-item"
        >
          <el-icon><component :is="item.icon" /></el-icon>
          <span>{{ item.label }}</span>
        </router-link>
      </nav>
    </aside>

    <section class="admin-content">
      <header class="admin-topbar">
        <div>
          <span>独立管理端</span>
          <strong>{{ activeTitle }}</strong>
        </div>
        <div class="topbar-user">
          <span class="user-name">{{ authStore.realName }}</span>
          <el-button plain @click="handleLogout">退出管理端</el-button>
        </div>
      </header>

      <router-view v-slot="{ Component }">
        <transition name="page-fade" mode="out-in">
          <component :is="Component" :key="route.fullPath" />
        </transition>
      </router-view>
    </section>

    <!-- 强制改密对话框：mustChangePassword=true 时模态展示 -->
    <ChangePasswordDialog />
  </div>
</template>

<style scoped>
.admin-frame {
  display: grid;
  grid-template-columns: 252px minmax(0, 1fr);
  min-height: 100dvh;
  background: var(--zy-bg);
}

.admin-sidebar {
  position: sticky;
  top: 0;
  height: 100dvh;
  padding: 18px 14px;
  border-right: 1px solid var(--zy-line);
  background: #fff;
}

.admin-brand {
  display: flex;
  align-items: center;
  gap: 12px;
  min-height: 54px;
  padding: 4px 4px 18px;
}

.admin-brand img {
  width: 42px;
  height: 42px;
  border: 1px solid var(--zy-line);
  border-radius: 12px;
  object-fit: contain;
}

.admin-brand strong,
.admin-brand span,
.admin-topbar strong,
.admin-topbar span {
  display: block;
}

.admin-brand strong,
.admin-topbar strong {
  color: var(--zy-ink);
}

.admin-brand span,
.admin-topbar span {
  color: var(--zy-muted);
  font-size: 12px;
  font-weight: 800;
}

.admin-nav {
  display: grid;
  gap: 7px;
}

.admin-nav-item {
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

.admin-nav-item:hover,
.admin-nav-item.router-link-active {
  color: var(--zy-brand-strong);
  background: var(--zy-brand-soft);
}

.admin-content {
  min-width: 0;
  padding: 18px 24px 32px;
}

.admin-topbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  min-height: 56px;
  margin-bottom: 22px;
}

.topbar-user {
  display: flex;
  align-items: center;
  gap: 12px;
}

.user-name {
  color: var(--zy-ink);
  font-size: 14px;
  font-weight: 800;
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

@media (max-width: 860px) {
  .admin-frame {
    grid-template-columns: 1fr;
  }

  .admin-sidebar {
    position: sticky;
    z-index: var(--zy-z-sticky);
    height: auto;
    border-right: 0;
    border-bottom: 1px solid var(--zy-line);
  }

  .admin-brand {
    display: none;
  }

  .admin-nav {
    grid-template-columns: repeat(4, minmax(0, 1fr));
  }

  .admin-nav-item {
    justify-content: center;
    min-width: 0;
    padding: 0 8px;
    font-size: 12px;
  }
}
</style>
