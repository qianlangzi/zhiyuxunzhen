<script setup lang="ts">
import { computed } from 'vue'
import { useAuthStore } from '../stores/auth'

const authStore = useAuthStore()

const roleLabel = computed(() => {
  const labels: Record<number, string> = {
    2: '教学秘书',
    3: '教研室主任',
    5: '运维',
  }
  return labels[authStore.role ?? -1] ?? '当前角色'
})
</script>

<template>
  <main class="admin-page">
    <section class="no-access-card surface-card">
      <el-icon :size="48" color="var(--zy-muted)"><WarningFilled /></el-icon>
      <h1>暂无可用功能</h1>
      <p>当前角色（{{ roleLabel }}）在管理端暂无可用页面。</p>
      <p v-if="authStore.role === 2" class="hint">
        学生批量导入功能正在开发中，届时将通过独立页面提供。
      </p>
      <el-button type="primary" @click="authStore.logout()">退出登录</el-button>
    </section>
  </main>
</template>

<style scoped>
.no-access-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 14px;
  padding: 60px 24px;
  text-align: center;
}

.no-access-card h1 {
  margin: 0;
  color: var(--zy-ink);
  font-size: 24px;
}

.no-access-card p {
  margin: 0;
  color: var(--zy-muted);
  font-size: 14px;
  font-weight: 800;
}

.no-access-card .hint {
  max-width: 360px;
  line-height: 1.6;
}
</style>
