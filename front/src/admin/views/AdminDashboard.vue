<script setup lang="ts">
import { adminStats, auditLogs, caseAudits } from '@/views/mockData'
</script>

<template>
  <main class="admin-page">
    <section class="admin-page-head">
      <div>
        <span>全局驾驶舱</span>
        <h1>平台运行与教学运营总览</h1>
      </div>
      <el-button type="primary">查看待办审核</el-button>
    </section>

    <section class="stats-grid">
      <article v-for="item in adminStats" :key="item.label" class="surface-card stat-card">
        <span>{{ item.label }}</span>
        <strong>{{ item.value }}</strong>
        <p>{{ item.detail }}</p>
      </article>
    </section>

    <section class="dashboard-grid">
      <article class="surface-card panel">
        <div class="panel-head">
          <h2 class="admin-section-title">待办审核</h2>
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
          <h2 class="admin-section-title">最近敏感操作</h2>
          <router-link to="/logs">查看全部</router-link>
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
