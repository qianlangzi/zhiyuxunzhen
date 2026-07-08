<script setup lang="ts">
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import brandLogo from '@/assets/brand-logo.png'

const route = useRoute()

const navItems = [
  { label: '全局驾驶舱', path: '/', icon: 'DataBoard' },
  { label: '审核中心', path: '/audits', icon: 'Checked' },
  { label: '系统配置', path: '/config', icon: 'Setting' },
  { label: '审计日志', path: '/logs', icon: 'Tickets' }
]

const activeTitle = computed(() => navItems.find((item) => item.path === route.path)?.label || '全局驾驶舱')
</script>

<template>
  <div class="admin-frame">
    <aside class="admin-sidebar" aria-label="管理端导航">
      <div class="admin-brand">
        <img :src="brandLogo" alt="" />
        <div>
          <strong>智愈寻真</strong>
          <span>Admin Console</span>
        </div>
      </div>

      <nav class="admin-nav">
        <router-link v-for="item in navItems" :key="item.path" :to="item.path" class="admin-nav-item">
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
        <el-button plain>退出管理端</el-button>
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
  gap: 6px;
}

.admin-nav-item {
  display: flex;
  align-items: center;
  gap: 12px;
  min-height: 44px;
  padding: 0 12px;
  border-radius: 14px;
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
