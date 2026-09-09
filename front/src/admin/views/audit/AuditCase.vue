<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  listCaseAudits,
  approveCase,
  rejectCase,
  getCaseAuditDetail,
  type CaseAuditDetail,
  type CaseAuditItem,
} from '../../api/teacherAudit'
import { fmtDateTime, tableDateTime } from '../../utils/format'
import AuditStatusFilter from './AuditStatusFilter.vue'

const list = ref<CaseAuditItem[]>([])
const total = ref(0)
const loading = ref(false)
const pager = reactive({ pageNum: 1, pageSize: 10 })
const auditStatus = ref<number | undefined>(undefined)

const loadList = async () => {
  loading.value = true
  try {
    const page = await listCaseAudits(pager.pageNum, pager.pageSize, auditStatus.value)
    list.value = page.list ?? []
    total.value = page.total ?? 0
  } catch {
    // 错误由 http 拦截器提示
  } finally {
    loading.value = false
  }
}

const onFilterChange = (v?: number) => {
  auditStatus.value = v
  pager.pageNum = 1
  loadList()
}

// ---------- 详情弹窗 ----------
const detailVisible = ref(false)
const detailLoading = ref(false)
const detail = ref<CaseAuditDetail | null>(null)

const openDetail = async (caseId: number) => {
  detailVisible.value = true
  detailLoading.value = true
  detail.value = null
  try {
    detail.value = await getCaseAuditDetail(caseId)
  } catch {
    detailVisible.value = false
  } finally {
    detailLoading.value = false
  }
}

/** 安全解析 JSON 字符串，解析失败返回 null */
function parseJson<T>(raw?: string | null): T | null {
  if (!raw || !raw.trim()) return null
  try {
    return JSON.parse(raw) as T
  } catch {
    return null
  }
}

/** 知识点标签数组（JSON 数组） */
const tagsList = (raw?: string | null): string[] => parseJson<string[]>(raw) ?? []

/** 评分要点数组 [{label,fullMark,criteria,deduct}] */
const scorePoints = (raw?: string | null): ScorePoint[] => parseJson<ScorePoint[]>(raw) ?? []

interface ScorePoint {
  label?: string
  fullMark?: number
  criteria?: string
  deduct?: number
}

/** 结构化 JSON（画像/检查/标准路径）以键值对展示 */
function jsonEntries(raw?: string | null): { key: string; value: unknown }[] {
  const obj = parseJson<Record<string, unknown>>(raw)
  if (!obj) return []
  return Object.entries(obj).map(([key, value]) => ({
    key,
    value: typeof value === 'string' ? value : JSON.stringify(value),
  }))
}

const handleApprove = async (item: CaseAuditItem) => {
  try {
    await ElMessageBox.confirm(
      `确认通过病例「${item.title}」的审核？`,
      '通过审核',
      { confirmButtonText: '通过', cancelButtonText: '取消', type: 'warning' },
    )
  } catch {
    return
  }
  try {
    await approveCase(item.caseId)
    ElMessage.success('已通过审核')
    await loadList()
  } catch {
    // 业务失败由 http 拦截器提示
  }
}

const handleReject = async (item: CaseAuditItem) => {
  try {
    await ElMessageBox.confirm(
      `确认驳回病例「${item.title}」的审核？`,
      '驳回审核',
      { confirmButtonText: '驳回', cancelButtonText: '取消', type: 'warning' },
    )
  } catch {
    return
  }
  try {
    await rejectCase(item.caseId)
    ElMessage.success('已驳回')
    await loadList()
  } catch {
    // 业务失败由 http 拦截器提示
  }
}

const difficultyText = (d: number) =>
  ({ 1: '简单', 2: '标准', 3: '困难' } as Record<number, string>)[d] ?? '-'

const auditStatusMap = (s: number) => {
  switch (s) {
    case 1:
      return { text: '待审核', type: 'warning' as const }
    case 2:
      return { text: '已通过', type: 'success' as const }
    case 3:
      return { text: '已驳回', type: 'danger' as const }
    default:
      return { text: '未知', type: 'info' as const }
  }
}

const onPageChange = () => loadList()
const onSizeChange = () => {
  pager.pageNum = 1
  loadList()
}

onMounted(loadList)
</script>

<template>
  <section class="surface-card audit-panel">
    <div class="panel-toolbar">
      <AuditStatusFilter :model-value="auditStatus" @update:model-value="onFilterChange" />
      <span class="panel-total">共 {{ total }} 条</span>
    </div>
    <el-table v-loading="loading" :data="list" stripe>
      <template #empty>
        <div class="empty-tip">暂无病例记录</div>
      </template>
      <el-table-column prop="title" label="病例标题" min-width="220" show-overflow-tooltip />
      <el-table-column prop="department" label="科室" width="140">
        <template #default="{ row }">{{ row.department || '-' }}</template>
      </el-table-column>
      <el-table-column label="难度" width="90">
        <template #default="{ row }">
          <el-tag effect="plain">{{ difficultyText(row.difficulty) }}</el-tag>
        </template>
      </el-table-column>
      <el-table-column prop="creatorName" label="提交教师" width="120" />
      <el-table-column label="审核状态" width="110">
        <template #default="{ row }">
          <el-tag :type="auditStatusMap(row.auditStatus).type" effect="plain">
            {{ auditStatusMap(row.auditStatus).text }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column prop="createdAt" label="提交时间" width="160" :formatter="tableDateTime" />
      <el-table-column label="操作" width="220" fixed="right">
        <template #default="{ row }">
          <el-button size="small" type="primary" link @click="openDetail(row.caseId)">
            查看详情
          </el-button>
          <template v-if="row.auditStatus === 1">
            <el-button size="small" type="success" link @click="handleApprove(row)">
              通过
            </el-button>
            <el-button size="small" type="danger" plain @click="handleReject(row)">
              驳回
            </el-button>
          </template>
          <span v-if="row.auditStatus !== 1" class="muted-text">—</span>
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
        @current-change="onPageChange"
        @size-change="onSizeChange"
      />
    </div>

    <!-- 详情弹窗 -->
    <el-dialog
      v-model="detailVisible"
      title="病例审核详情"
      width="760px"
      :close-on-click-modal="false"
    >
      <div v-loading="detailLoading" class="detail-body">
        <template v-if="detail">
          <div class="detail-head">
            <h2>{{ detail.title }}</h2>
            <div class="detail-meta">
              <el-tag effect="plain">{{ detail.department || '-' }}</el-tag>
              <el-tag effect="plain">{{ difficultyText(detail.difficulty) }}</el-tag>
              <el-tag :type="auditStatusMap(detail.adminAuditStatus).type" effect="plain">
                {{ auditStatusMap(detail.adminAuditStatus).text }}
              </el-tag>
              <span>发布者：{{ detail.creatorName || detail.creatorId }}</span>
              <span>提交时间：{{ fmtDateTime(detail.createdAt) }}</span>
            </div>
          </div>

          <template v-if="jsonEntries(detail.patientProfile).length">
            <h3 class="detail-title">患者画像</h3>
            <div class="kv-list">
              <div v-for="e in jsonEntries(detail.patientProfile)" :key="e.key" class="kv">
                <span class="kv-key">{{ e.key }}</span>
                <span class="kv-val">{{ e.value }}</span>
              </div>
            </div>
          </template>

          <template v-if="tagsList(detail.knowledgeTags).length">
            <h3 class="detail-title">知识点</h3>
            <div class="tag-wrap">
              <el-tag v-for="t in tagsList(detail.knowledgeTags)" :key="t" effect="plain">
                {{ t }}
              </el-tag>
            </div>
          </template>

          <template v-if="detail.hiddenDisease">
            <h3 class="detail-title">隐藏疾病</h3>
            <p class="detail-text">{{ detail.hiddenDisease }}</p>
          </template>

          <template v-if="jsonEntries(detail.presetExams).length">
            <h3 class="detail-title">预设检查</h3>
            <div class="kv-list">
              <div v-for="e in jsonEntries(detail.presetExams)" :key="e.key" class="kv">
                <span class="kv-key">{{ e.key }}</span>
                <span class="kv-val">{{ e.value }}</span>
              </div>
            </div>
          </template>

          <template v-if="jsonEntries(detail.standardPath).length">
            <h3 class="detail-title">标准问诊/诊断路径</h3>
            <div class="kv-list">
              <div v-for="e in jsonEntries(detail.standardPath)" :key="e.key" class="kv">
                <span class="kv-key">{{ e.key }}</span>
                <span class="kv-val">{{ e.value }}</span>
              </div>
            </div>
          </template>

          <template v-if="detail.referenceAnswer">
            <h3 class="detail-title">标准答案 / 诊断要点</h3>
            <p class="detail-text">{{ detail.referenceAnswer }}</p>
          </template>

          <template v-if="scorePoints(detail.scoringPoints).length">
            <h3 class="detail-title">评分要点</h3>
            <div class="score-list">
              <div
                v-for="(p, i) in scorePoints(detail.scoringPoints)"
                :key="i"
                class="score-item"
              >
                <b>{{ p.label || `要点 ${i + 1}` }}</b>
                <span v-if="p.fullMark != null" class="score-mark">满分 {{ p.fullMark }}</span>
                <span v-if="p.deduct != null" class="score-deduct">扣分 {{ p.deduct }}</span>
                <p class="score-criteria">{{ p.criteria || '-' }}</p>
              </div>
            </div>
          </template>

          <div v-if="detail.sourceCaseId" class="detail-note">
            引用来源病例：#{{ detail.sourceCaseId }}
          </div>
        </template>
      </div>
    </el-dialog>
  </section>
</template>

<style scoped>
.audit-panel {
  padding: 16px;
}

.panel-toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  min-height: 32px;
  margin-bottom: 8px;
}

.panel-total {
  color: var(--zy-muted);
  font-size: 13px;
  font-weight: 800;
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

.muted-text {
  color: var(--zy-muted);
  font-size: 13px;
}

.detail-body {
  min-height: 120px;
}

.detail-head {
  padding-bottom: 12px;
  margin-bottom: 8px;
  border-bottom: 1px solid var(--zy-line);
}

.detail-head h2 {
  margin: 0 0 8px;
  color: var(--zy-ink);
  font-size: 17px;
}

.detail-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  align-items: center;
  color: var(--zy-muted);
  font-size: 13px;
}

.detail-title {
  margin: 18px 0 8px;
  color: var(--zy-ink);
  font-size: 14px;
  font-weight: 800;
}

.detail-text {
  margin: 0;
  color: var(--zy-ink);
  line-height: 1.7;
  white-space: pre-wrap;
}

.kv-list {
  display: grid;
  gap: 6px;
}

.kv {
  display: flex;
  gap: 12px;
  padding: 7px 10px;
  border-radius: 8px;
  background: var(--zy-surface-soft);
  font-size: 13px;
}

.kv-key {
  flex: none;
  min-width: 84px;
  color: var(--zy-muted);
  font-weight: 800;
}

.kv-val {
  color: var(--zy-ink);
  line-height: 1.6;
}

.tag-wrap {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.score-list {
  display: grid;
  gap: 8px;
}

.score-item {
  padding: 10px 12px;
  border: 1px solid var(--zy-line);
  border-radius: 10px;
  background: #fff;
}

.score-item b {
  color: var(--zy-ink);
}

.score-mark,
.score-deduct {
  margin-left: 10px;
  color: var(--zy-brand-strong);
  font-size: 12px;
  font-weight: 800;
}

.score-deduct {
  color: var(--zy-danger);
}

.score-criteria {
  margin: 6px 0 0;
  color: var(--zy-ink);
  font-size: 13px;
  line-height: 1.6;
}

.detail-note {
  margin-top: 14px;
  color: var(--zy-muted);
  font-size: 13px;
}
</style>