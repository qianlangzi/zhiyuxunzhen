<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { getDashboard } from '../api/dashboard'
import type { DashboardVO } from '../types'
import { auditLogs, caseAudits } from '@/views/mockData'

// ---------- Dashboard 真实数据 ----------
const dashboardData = ref<DashboardVO | null>(null)
const loading = ref(false)

const stats = computed(() => {
  if (!dashboardData.value) return []
  const d = dashboardData.value
  return [
    { label: '今日活跃学生', value: d.todayActiveStudents, detail: '今日登录并参与学习' },
    { label: '认证教师', value: d.activeTeachers, detail: '已通过资质审核' },
    { label: '问诊会话', value: d.chatSessionCount, detail: '累计 AI 问诊会话' },
    { label: '作业提交', value: d.assignmentSubmitCount, detail: '累计学生作业提交' },
    { label: '待审病例', value: d.pendingCaseAuditCount, detail: '等待审核的病例' },
    { label: '待审教师', value: d.pendingTeacherAuditCount, detail: '等待资质审核' },
    { label: '官方病例', value: d.officialCaseCount, detail: '已发布认证病例' },
  ]
})

async function fetchDashboard(): Promise<void> {
  loading.value = true
  try {
    dashboardData.value = await getDashboard()
  } catch {
    // http.ts 已处理错误提示
  } finally {
    loading.value = false
  }
}

onMounted(fetchDashboard)
</script>

<template>
  <main class="admin-page">
    <section class="admin-page-head">
      <div>
        <span>全局驾驶舱</span>
        <h1>平台运行与教学运营总览</h1>
      </div>
      <el-button :loading="loading" plain @click="fetchDashboard">刷新数据</el-button>
    </section>

    <!-- 统计卡片：真实数据 -->
    <section v-loading="loading" class="stats-grid">
      <article
        v-for="item in stats"
        :key="item.label"
        class="surface-card stat-card interactive"
      >
        <span>{{ item.label }}</span>
        <strong>{{ item.value }}</strong>
        <p>{{ item.detail }}</p>
      </article>
      <article v-if="stats.length === 0 && !loading" class="surface-card stat-card">
        <span>暂无数据</span>
      </article>
    </section>

    <!-- 待办审核 & 敏感操作：暂为 Mock，后续接真实接口 -->
    <section class="dashboard-grid">
      <article class="surface-card panel">
        <div class="panel-head">
          <div class="panel-title">
            <h2 class="admin-section-title">待办审核</h2>
            <el-tag size="small" type="warning" effect="plain">Mock</el-tag>
          </div>
          <el-tag type="danger" effect="plain">{{ caseAudits.filter((item) => item.status === '待审').length }} 项</el-tag>
        </div>
        <div v-for="item in caseAudits" :key="item.title" class="list-row">
          <div>
            <strong>{{ item.title }}</strong>
            <span>{{ item.owner }} · {{ item.risk }}</span>
          </div>
          <el-tag effect="plain">{{ item.status }}</el-tag>
        </div>
      </article>

      <article class="surface-card panel">
        <div class="panel-head">
          <div class="panel-title">
            <h2 class="admin-section-title">最近敏感操作</h2>
            <el-tag size="small" type="warning" effect="plain">Mock</el-tag>
          </div>
        </div>
        <div v-for="item in auditLogs" :key="`${item.time}-${item.action}`" class="list-row">
          <div>
            <strong>{{ item.action }}</strong>
            <span>{{ item.time }} · {{ item.operator }} · {{ item.target }}</span>
          </div>
        </div>
      </article>
    </section>
  </main>
</template>

<style scoped>
.stats-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 16px;
}

.stat-card,
.panel {
  padding: 20px;
}

.stat-card span,
.stat-card p,
.list-row span {
  color: var(--zy-muted);
  font-size: 13px;
  font-weight: 800;
}

.stat-card strong {
  display: block;
  margin-top: 10px;
  color: var(--zy-ink);
  font-size: 34px;
}

.stat-card p {
  margin: 8px 0 0;
}

.dashboard-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}

.panel-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
  margin-bottom: 8px;
}

.panel-title {
  display: flex;
  align-items: center;
  gap: 8px;
}

.panel-head a {
  color: var(--zy-brand-strong);
  font-size: 13px;
  font-weight: 800;
  text-decoration: none;
}

.list-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 16px 0;
  border-top: 1px solid var(--zy-line);
}

.list-row strong,
.list-row span {
  display: block;
}

.list-row strong {
  color: var(--zy-ink);
}

@media (max-width: 1100px) {
  .stats-grid,
  .dashboard-grid {
    grid-template-columns: 1fr 1fr;
  }
}

@media (max-width: 760px) {
  .stats-grid,
  .dashboard-grid {
    grid-template-columns: 1fr;
  }
}
</style>
