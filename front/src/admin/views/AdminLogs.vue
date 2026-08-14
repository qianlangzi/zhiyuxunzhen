<script setup lang="ts">
import { computed, ref } from 'vue'
import { auditLogs } from '@/views/mockData'

const keyword = ref('')

const filteredLogs = computed(() => {
  if (!keyword.value) return auditLogs
  return auditLogs.filter((item) =>
    [item.time, item.operator, item.action, item.target].some((value) => value.includes(keyword.value))
  )
})
</script>

<template>
  <main class="admin-page">
    <section class="admin-page-head">
      <div>
        <span>审计日志</span>
        <h1>追踪所有敏感操作</h1>
      </div>
      <el-button plain disabled>导出日志</el-button>
    </section>

    <el-alert
      type="warning"
      :closable="false"
      show-icon
      class="demo-alert"
      title="演示模式"
      description="当前页面尚未对接后端接口，所示日志为示例数据，导出操作已禁用。"
    />

    <section class="surface-card log-panel">
      <div class="filter-row">
        <el-input v-model="keyword" placeholder="搜索操作人、动作或对象" clearable>
          <template #prefix>
            <el-icon><Search /></el-icon>
          </template>
        </el-input>
      </div>
      <el-table :data="filteredLogs" stripe>
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
.demo-alert {
  margin-bottom: 16px;
}

.log-panel {
  padding: 12px;
}

.filter-row {
  max-width: 360px;
  margin: 4px 4px 14px;
}
</style>
