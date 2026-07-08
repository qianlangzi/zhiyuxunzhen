<script setup lang="ts">
import { useUserStore } from '@/stores/user'
import { computed } from 'vue'

const user = useUserStore()
const roleName = computed(() => (user.role === 1 ? '教师端' : '学生端'))
</script>

<template>
  <main class="profile-page">
    <section class="page-head">
      <span>个人资料</span>
      <h1>{{ user.username || '未命名用户' }}</h1>
    </section>

    <section class="surface-card profile-card">
      <div>
        <span>当前身份</span>
        <strong>{{ roleName }}</strong>
      </div>
      <div>
        <span>账号</span>
        <strong>{{ user.username || '-' }}</strong>
      </div>
      <div>
        <span>说明</span>
        <strong>系统内容仅用于医学思维训练。</strong>
      </div>
    </section>
  </main>
</template>

<style scoped>
.profile-page {
  display: grid;
  gap: 20px;
}

.page-head span {
  color: var(--zy-muted);
  font-size: 13px;
  font-weight: 800;
}

.page-head h1 {
  margin: 6px 0 0;
  color: var(--zy-ink);
  font-size: clamp(26px, 3vw, 34px);
}

.profile-card {
  display: grid;
  gap: 18px;
  max-width: 680px;
  padding: 20px;
}

.profile-card span,
.profile-card strong {
  display: block;
}

.profile-card span {
  color: var(--zy-muted);
  font-size: 13px;
  font-weight: 800;
}

.profile-card strong {
  margin-top: 4px;
  color: var(--zy-ink);
}
</style>
