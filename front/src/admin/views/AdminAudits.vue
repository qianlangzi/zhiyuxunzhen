<script setup lang="ts">
import { caseAudits, teacherAudits } from '@/views/mockData'
</script>

<template>
  <main class="admin-page">
    <section class="admin-page-head">
      <div>
        <span>审核中心</span>
        <h1>教师资质与病例内容终审</h1>
      </div>
    </section>

    <el-alert
      type="warning"
      :closable="false"
      show-icon
      class="demo-alert"
      title="演示模式"
      description="当前页面尚未对接后端接口，所示审核数据为示例，通过/退回操作已禁用。"
    />

    <section class="audit-grid">
      <article class="surface-card audit-panel">
        <h2 class="admin-section-title">教师入驻审核</h2>
        <div v-for="item in teacherAudits" :key="item.name" class="audit-row">
          <div>
            <strong>{{ item.name }}</strong>
            <span>{{ item.org }} · {{ item.credential }}</span>
          </div>
          <div class="action-row">
            <el-tag effect="plain">{{ item.status }}</el-tag>
            <el-button v-if="item.status === '待审核'" size="small" type="primary" disabled>
              通过
            </el-button>
            <el-button v-if="item.status === '待审核'" size="small" plain disabled>
              退回
            </el-button>
          </div>
        </div>
      </article>

      <article class="surface-card audit-panel">
        <h2 class="admin-section-title">病例广场审核</h2>
        <div v-for="item in caseAudits" :key="item.title" class="audit-row">
          <div>
            <strong>{{ item.title }}</strong>
            <span>{{ item.owner }} · {{ item.risk }}</span>
          </div>
          <div class="action-row">
            <el-tag :type="item.status === '通过' ? 'success' : 'warning'" effect="plain">{{ item.status }}</el-tag>
            <el-button v-if="item.status === '待审'" size="small" plain disabled>
              模拟审阅
            </el-button>
          </div>
        </div>
      </article>
    </section>
  </main>
</template>

<style scoped>
.demo-alert {
  margin-bottom: 16px;
}

.audit-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}

.audit-panel {
  padding: 20px;
}

.audit-row {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 16px;
  align-items: center;
  padding: 16px 0;
  border-top: 1px solid var(--zy-line);
}

.audit-row strong,
.audit-row span {
  display: block;
}

.audit-row strong {
  color: var(--zy-ink);
}

.audit-row span {
  margin-top: 4px;
  color: var(--zy-muted);
  font-size: 13px;
  font-weight: 800;
}

.action-row {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: flex-end;
  gap: 8px;
}

@media (max-width: 980px) {
  .audit-grid,
  .audit-row {
    grid-template-columns: 1fr;
  }

  .action-row {
    justify-content: flex-start;
  }
}
</style>
