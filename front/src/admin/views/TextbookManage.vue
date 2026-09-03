<script setup lang="ts">
import { onBeforeUnmount, onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  IngestStatus,
  listTextbooks,
  TextbookStatus,
  toggleTextbookStatus,
  triggerIngest,
  getIngestTaskDetail,
  type TextbookItem,
  type IngestTaskDetail,
} from '../api/textbookManage'

// ---------- 列表与分页 ----------
const listRef = ref<TextbookItem[]>([])
const total = ref(0)
const loading = ref(false)
const pager = reactive({ pageNum: 1, pageSize: 10 })

const loadList = async () => {
  loading.value = true
  try {
    const page = await listTextbooks(pager.pageNum, pager.pageSize)
    listRef.value = page.list ?? []
    total.value = page.total ?? 0
  } catch {
    // 错误统一由 http 拦截器 ElMessage 提示，这里仅停止 loading
  } finally {
    loading.value = false
  }
}

// ---------- 上架 / 下架状态渲染 ----------
const statusLabel = (val: number) => (val === TextbookStatus.ON_SHELF ? '上架' : '下架')
const statusType = (val: number) =>
  val === TextbookStatus.ON_SHELF ? 'success' : 'info'

const ingestLabel = (val: number) => {
  switch (val) {
    case IngestStatus.PROCESSING:
      return '处理中'
    case IngestStatus.DONE:
      return '已入库'
    case IngestStatus.FAILED:
      return '失败'
    default:
      return '未入库'
  }
}
const ingestType = (val: number) => {
  switch (val) {
    case IngestStatus.PROCESSING:
      return 'warning'
    case IngestStatus.DONE:
      return 'success'
    case IngestStatus.FAILED:
      return 'danger'
    default:
      return 'info'
  }
}

// ---------- 入向量库 ----------
const ingestLoadingId = ref<number | null>(null)
const handleIngest = async (item: TextbookItem) => {
  if (ingestLoadingId.value !== null) return
  ingestLoadingId.value = item.id
  try {
    await triggerIngest(item.id)
    ElMessage.success('已触发，入库中')
    await loadList()
  } catch {
    // 业务失败已由 http 拦截器提示
  } finally {
    ingestLoadingId.value = null
  }
}

// ---------- 上架 / 下架切换 ----------
const togglingId = ref<number | null>(null)
const handleToggle = async (item: TextbookItem) => {
  const action = item.status === TextbookStatus.ON_SHELF ? '下架' : '上架'
  try {
    await ElMessageBox.confirm(
      `确认${action}教材「${item.title}」？`,
      action,
      { confirmButtonText: action, cancelButtonText: '取消', type: 'warning' },
    )
  } catch {
    return // 用户取消
  }
  togglingId.value = item.id
  try {
    await toggleTextbookStatus(item.id)
    ElMessage.success(`已${action}`)
    await loadList()
  } catch {
    // 业务失败已由 http 拦截器提示
  } finally {
    togglingId.value = null
  }
}

const handlerSizeChange = () => {
  pager.pageNum = 1
  loadList()
}

// ---------- 详情弹窗（教材已含完整字段，直接展示行数据）----------
const detailVisible = ref(false)
const detailRow = ref<TextbookItem | null>(null)

const openDetail = (row: TextbookItem) => {
  detailRow.value = row
  detailVisible.value = true
}

// ---------- 入库任务详情弹窗（任务 ID/尝试次数/错误信息）----------
const taskVisible = ref(false)
const taskLoading = ref(false)
const taskDetail = ref<IngestTaskDetail | null>(null)
const taskRow = ref<TextbookItem | null>(null)

const openTaskDetail = async (row: TextbookItem) => {
  taskRow.value = row
  taskVisible.value = true
  await refreshTaskDetail()
}

const refreshTaskDetail = async () => {
  if (!taskRow.value) return
  taskLoading.value = true
  try {
    taskDetail.value = await getIngestTaskDetail(taskRow.value.id)
  } catch {
    taskDetail.value = null
  } finally {
    taskLoading.value = false
  }
}

const taskStatusLabel = (status?: string | null) => {
  switch (status) {
    case 'SUCCEEDED':
      return '已完成'
    case 'FAILED_FINAL':
      return '最终失败'
    case 'FAILED_RETRYABLE':
      return '失败（可重试）'
    case 'RUNNING':
      return '运行中'
    case 'PENDING':
      return '排队中'
    case 'NONE':
      return '未触发'
    case 'AI_TASK_UNAVAILABLE':
      return '任务不可达'
    default:
      return status || '-'
  }
}
const taskStatusType = (status?: string | null) => {
  switch (status) {
    case 'SUCCEEDED':
      return 'success'
    case 'FAILED_FINAL':
    case 'FAILED_RETRYABLE':
      return 'danger'
    case 'RUNNING':
    case 'PENDING':
      return 'warning'
    default:
      return 'info'
  }
}

onMounted(loadList)

// 异步入库完成由 AI 回调更新，处理中时自动刷新列表让管理员能看到最终状态。
const statusTimer = window.setInterval(() => {
  if (!loading.value && listRef.value.some((item) => item.ingestStatus === IngestStatus.PROCESSING)) {
    void loadList()
  }
}, 5000)

onBeforeUnmount(() => window.clearInterval(statusTimer))
</script>

<template>
  <main class="admin-page">
    <section class="surface-card audit-panel">
      <el-table v-loading="loading" :data="listRef" stripe>
        <template #empty>
          <div class="empty-tip">暂无教材，请先上传</div>
        </template>
        <el-table-column prop="title" label="教材标题" min-width="200" show-overflow-tooltip />
        <el-table-column prop="department" label="学科" width="140" />
        <el-table-column prop="author" label="作者" width="140">
          <template #default="{ row }">
            {{ row.author || '-' }}
          </template>
        </el-table-column>
        <el-table-column prop="creatorName" label="上传教师" width="120" />
        <el-table-column label="状态" width="120">
          <template #default="{ row }">
            <el-tag :type="statusType(row.status)" effect="plain">
              {{ statusLabel(row.status) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="入库状态" width="100">
          <template #default="{ row }">
            <el-tag :type="ingestType(row.ingestStatus)" effect="plain">
              {{ ingestLabel(row.ingestStatus) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="最近入库时间" width="170">
          <template #default="{ row }">
            {{ row.lastIngestAt || '-' }}
          </template>
        </el-table-column>
        <el-table-column label="失败原因" min-width="220" show-overflow-tooltip>
          <template #default="{ row }">
            <span v-if="row.ingestStatus === IngestStatus.FAILED">{{ row.ingestError || 'AI 未返回具体原因' }}</span>
            <span v-else>-</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="300" fixed="right">
          <template #default="{ row }">
            <el-button size="small" type="primary" link @click="openDetail(row)">
              查看详情
            </el-button>
            <el-button size="small" type="info" link @click="openTaskDetail(row)">
              任务详情
            </el-button>
            <el-button
              size="small"
              type="primary"
              link
              :loading="ingestLoadingId === row.id"
              :disabled="row.ingestStatus === IngestStatus.PROCESSING"
              @click="handleIngest(row)"
            >
              {{ row.ingestStatus === IngestStatus.FAILED ? '重试入库' : row.ingestStatus === IngestStatus.DONE ? '重新入库' : '入向量库' }}
            </el-button>
            <el-button
              size="small"
              :type="row.status === TextbookStatus.ON_SHELF ? 'danger' : 'success'"
              link
              :loading="togglingId === row.id"
              @click="handleToggle(row)"
            >
              {{ row.status === TextbookStatus.ON_SHELF ? '下架' : '上架' }}
            </el-button>
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

    <!-- 详情弹窗 -->
    <el-dialog
      v-model="detailVisible"
      title="教材详情"
      width="640px"
      :close-on-click-modal="false"
    >
      <div v-if="detailRow" class="tb-detail">
        <div class="tb-head">
          <div v-if="detailRow.coverUrl" class="tb-cover">
            <el-image :src="detailRow.coverUrl" fit="contain" :preview-src-list="[detailRow.coverUrl]" />
          </div>
          <div class="tb-info">
            <h2>{{ detailRow.title }}</h2>
            <p>
              <el-tag :type="statusType(detailRow.status)" effect="plain">
                {{ statusLabel(detailRow.status) }}
              </el-tag>
              <el-tag :type="ingestType(detailRow.ingestStatus)" effect="plain">
                {{ ingestLabel(detailRow.ingestStatus) }}
              </el-tag>
            </p>
          </div>
        </div>

        <div class="kv-grid">
          <span>学科 <b>{{ detailRow.department || '-' }}</b></span>
          <span>版本 <b>{{ detailRow.edition || '-' }}</b></span>
          <span>作者 <b>{{ detailRow.author || '-' }}</b></span>
          <span>出版社 <b>{{ detailRow.publisher || '-' }}</b></span>
          <span>页数 <b>{{ detailRow.pageCount ?? '-' }}</b></span>
          <span>上传教师 <b>{{ detailRow.creatorName || '-' }}</b></span>
          <span>入库时间 <b>{{ detailRow.lastIngestAt || '-' }}</b></span>
          <span>入库次数 <b>{{ detailRow.ingestRetryCount ?? '-' }}</b></span>
          <span>最近任务ID <b class="mono-sm">{{ detailRow.ingestionId || '-' }}</b></span>
          <span v-if="detailRow.ingestStatus === IngestStatus.FAILED">失败原因 <b class="error-text">{{ detailRow.ingestError || 'AI 未返回具体原因' }}</b></span>
          <span>上传时间 <b>{{ detailRow.createdAt || '-' }}</b></span>
        </div>

        <template v-if="detailRow.description">
          <h3 class="tb-title">简介</h3>
          <p class="tb-desc">{{ detailRow.description }}</p>
        </template>

        <div v-if="detailRow.fileUrl" class="tb-file">
          电子书：
          <el-link type="primary" :href="detailRow.fileUrl" target="_blank">打开文件</el-link>
        </div>
      </div>
    </el-dialog>

    <!-- 入库任务详情弹窗 -->
    <el-dialog
      v-model="taskVisible"
      title="入库任务详情"
      width="560px"
      :close-on-click-modal="false"
    >
      <template #header>
        <span>入库任务详情</span>
        <el-button size="small" type="primary" link :loading="taskLoading" @click="refreshTaskDetail">
          <el-icon style="margin-right: 2px"><Refresh /></el-icon>刷新
        </el-button>
      </template>
      <div v-if="taskLoading" class="empty-tip" v-loading="taskLoading">正在查询 AI 中台任务…</div>
      <div v-else-if="taskDetail" class="tb-detail">
        <p v-if="taskRow" class="task-title">{{ taskRow.title }}</p>
        <div class="kv-grid">
          <span>任务 ID <b class="mono-sm">{{ taskDetail.ingestionId || '-' }}</b></span>
          <span>任务状态
            <el-tag :type="taskStatusType(taskDetail.status)" size="small" effect="plain">
              {{ taskStatusLabel(taskDetail.status) }}
            </el-tag>
          </span>
          <span>已尝试次数 <b>{{ taskDetail.attempts ?? '-' }}</b></span>
          <span>本地入库状态
            <el-tag :type="ingestType((taskDetail.ingestStatus ?? taskRow?.ingestStatus) ?? 0)" size="small" effect="plain">
              {{ ingestLabel((taskDetail.ingestStatus ?? taskRow?.ingestStatus) ?? 0) }}
            </el-tag>
          </span>
        </div>
        <template v-if="taskDetail.errorMessage">
          <h3 class="tb-title">最近错误</h3>
          <p class="tb-desc task-error">{{ taskDetail.errorMessage }}</p>
        </template>
        <template v-else-if="taskDetail.status === 'AI_TASK_UNAVAILABLE'">
          <h3 class="tb-title">提示</h3>
          <p class="tb-desc">{{ taskDetail.errorMessage }}</p>
        </template>
      </div>
      <div v-else class="empty-tip">任务详情读取失败，请确认后端与 AI 中台服务正常。</div>
    </el-dialog>
  </main>
</template>

<style scoped>
.audit-panel {
  padding: 12px;
}

.empty-tip {
  padding: 24px;
  color: var(--zy-muted);
}

.error-text {
  color: var(--el-color-danger);
  font-weight: 500;
}

.mono-sm {
  font-family: 'JetBrains Mono', Consolas, monospace;
  font-size: 12px;
  word-break: break-all;
}

.task-title {
  margin: 0 0 12px;
  color: var(--zy-ink);
  font-size: 15px;
  font-weight: 700;
}

.task-error {
  color: var(--el-color-danger);
  word-break: break-all;
}

.pager-row {
  display: flex;
  justify-content: flex-end;
  margin-top: 14px;
}

.tb-detail {
  min-height: 120px;
}

.tb-head {
  display: flex;
  gap: 16px;
  align-items: flex-start;
  padding-bottom: 12px;
  margin-bottom: 10px;
  border-bottom: 1px solid var(--zy-line);
}

.tb-cover {
  flex: none;
  width: 96px;
  height: 132px;
  padding: 4px;
  border: 1px solid var(--zy-line);
  border-radius: 10px;
  background: var(--zy-surface-soft);
}

.tb-cover .el-image {
  width: 100%;
  height: 100%;
}

.tb-info h2 {
  margin: 0 0 8px;
  color: var(--zy-ink);
  font-size: 17px;
}

.tb-info p {
  display: flex;
  gap: 6px;
  margin: 0;
}

.kv-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px 16px;
}

.kv-grid span {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 8px;
  padding-bottom: 6px;
  border-bottom: 1px dashed var(--zy-line);
  color: var(--zy-muted);
  font-size: 13px;
}

.kv-grid b {
  color: var(--zy-ink);
  font-weight: 700;
  text-align: right;
}

.tb-title {
  margin: 18px 0 8px;
  color: var(--zy-ink);
  font-size: 14px;
  font-weight: 800;
}

.tb-desc {
  margin: 0;
  color: var(--zy-ink);
  line-height: 1.7;
}

.tb-file {
  margin-top: 14px;
  color: var(--zy-ink);
  font-size: 13px;
}

@media (max-width: 560px) {
  .kv-grid {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 640px) {
  .tb-head {
    flex-direction: column;
  }
}
</style>
