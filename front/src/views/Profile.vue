<script setup lang="ts">
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { useUserStore } from '@/stores/user'

const router = useRouter()
const user = useUserStore()
const roleName = computed(() => (user.role === 1 ? '教师端' : '学生端'))

function logout() {
  user.logout()
  router.push('/login')
}
</script>

<template>
  <main class="profile-page">
    <section class="page-head">
      <div>
        <span>个人资料</span>
        <h1>{{ user.username || '未命名用户' }}</h1>
      </div>
      <el-button plain @click="logout">退出登录</el-button>
    </section>

    <section class="profile-grid">
      <article class="surface-card profile-card">
        <div class="avatar">{{ (user.username || '知').slice(0, 1).toUpperCase() }}</div>
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
          <strong>系统内容仅用于医学思维训练，不替代真实诊疗。</strong>
        </div>
      </article>

      <article class="surface-card profile-card">
        <div>
          <span>最近活动</span>
          <strong>{{ user.role === 1 ? '复核智能批阅结果' : '完成每日一例训练' }}</strong>
        </div>
        <div>
          <span>安全提醒</span>
          <strong>请勿上传真实患者姓名、身份证号或联系方式。</strong>
        </div>
      </article>
    </section>
  </main>
</template>

<style scoped>
.profile-page {
  display: grid;
  gap: 20px;
}

.profile-grid {
  display: grid;
  grid-template-columns: minmax(0, 680px) minmax(260px, 420px);
  gap: 16px;
}

.profile-card {
  display: grid;
  gap: 18px;
  padding: 20px;
}

.avatar {
  display: grid;
  place-items: center;
  width: 72px;
  height: 72px;
  border-radius: 22px;
  background: var(--zy-brand);
  color: #fff;
  font-size: 28px;
  font-weight: 900;
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
  line-height: 1.6;
}

@media (max-width: 980px) {
  .profile-grid {
    grid-template-columns: 1fr;
  }
}
</style>
