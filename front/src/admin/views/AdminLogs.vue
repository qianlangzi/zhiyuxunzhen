<script setup lang="ts">
import { auditLogs } from '@/views/mockData'
</script>

<template>
  <main class="admin-page">
    <section class="admin-page-head">
      <div>
        <span>审计日志</span>
        <h1>追踪所有敏感操作</h1>
      </div>
      <el-button plain>导出日志</el-button>
    </section>

    <section class="surface-card log-panel">
      <el-table :data="auditLogs" stripe>
        <el-table-column prop="time" label="时间" width="120" />
        <el-table-column prop="operator" label="操作人" width="160" />
        <el-table-column prop="action" label="操作类型" />
        <el-table-column prop="target" label="对象" />
        <el-table-column label="风险">
          <template #default="{ row }">
            <el-tag :type="row.action.includes('导出') ? 'warning' : 'success'" effect="plain">
              {{ row.action.includes('导出') ? '需留痕' : '正常' }}
            </el-tag>
          </template>
        </el-table-column>
      </el-table>
    </section>
  </main>
</template>

<style scoped>
.log-panel {
  padding: 12px;
}
</style>
