<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { listAuditLogs, type AuditLogItem } from '../api/auditLog'
import { fmtDateTime } from '../utils/format'

const logs = ref<AuditLogItem[]>([])
const total = ref(0)
const loading = ref(false)
const keyword = ref('')
const pager = reactive({ pageNum: 1, pageSize: 10 })

const loadList = async () => {
  loading.value = true
  try {
    const page = await listAuditLogs(
      pager.pageNum,
      pager.pageSize,
      keyword.value.trim() || undefined,
    )
    logs.value = page.list ?? []
    total.value = page.total ?? 0
  } catch {
    // 错误由 http 拦截器提示
  } finally {
    loading.value = false
  }
}

/** 本地二次过滤（后端为 action 匹配，这里再对操作人/对象做包含过滤） */
const filteredLogs = () => {
  const kw = keyword.value.trim()
  if (!kw) return logs.value
  return logs.value.filter((item) =>
    [item.operatorName, item.action, item.targetType]
      .some((v) => (v ?? '').toLowerCase().includes(kw.toLowerCase())),
  )
}

const formatTime = (iso: string | null) => fmtDateTime(iso)

const handlerSizeChange = () => {
  pager.pageNum = 1
  loadList()
}

onMounted(loadList)
</script>

<template>
  <main class="admin-page">
    <section class="admin-page-head">
      <div>
        <span>审计日志</span>
        <h1>追踪所有敏感操作</h1>
      </div>
    </section>

    <section class="surface-card log-panel">
      <div class="filter-row">
        <el-input
          v-model="keyword"
          placeholder="按操作类型 / 操作人 / 对象过滤"
          clearable
          @input="pager.pageNum = 1; loadList()"
        >
          <template #prefix>
            <el-icon><Search /></el-icon>
          </template>
        </el-input>
      </div>
      <el-table v-loading="loading" :data="filteredLogs()" stripe>
        <template #empty>
          <div class="empty-tip">暂无审计日志</div>
        </template>
        <el-table-column label="时间" width="150">
          <template #default="{ row }">{{ formatTime(row.createdAt) }}</template>
        </el-table-column>
        <el-table-column prop="operatorName" label="操作人" width="160" />
        <el-table-column prop="action" label="操作类型" />
        <el-table-column prop="targetType" label="对象类型" width="140">
          <template #default="{ row }">{{ row.targetType || '-' }}</template>
        </el-table-column>
        <el-table-column label="风险">
          <template #default="{ row }">
            <el-tag
              :type="row.action.includes('导出') ? 'warning' : 'success'"
              effect="plain"
            >
              {{ row.action.includes('导出') ? '需留痕' : '正常' }}
            </el-tag>
          </template>
        </el-table-column>
      </el-table>

      <div class="pager-row">
        <el-pagination
          v-model:current-page="pager.pageNum"
          v-model:page-size="pager.pageSize"
          :total="total"
          :page-sizes="[10, 20, 50]"
          layout="total, sizes, prev, pager, next, jumper"
          background
          @current-change="loadList"
          @size-change="handlerSizeChange"
        />
      </div>
    </section>
  </main>
</template>

<style scoped>
.log-panel {
  padding: 12px;
}

.filter-row {
  max-width: 360px;
  margin: 4px 4px 14px;
}

.empty-tip {
  padding: 24px;
  color: var(--zy-muted);
}

.pager-row {
  display: flex;
  justify-content: flex-end;
  margin-top: 14px;
}
</style>