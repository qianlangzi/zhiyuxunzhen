<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  approveQuestion,
  getQuestionAuditDetail,
  listQuestionAudits,
  rejectQuestion,
  type QuestionAuditDetail,
  type QuestionAuditItem,
} from '../api/questionAudit'
import { tableDateTime } from '../utils/format'
import AuditStatusFilter from './audit/AuditStatusFilter.vue'

// ---------- 列表与分页 ----------
const listRef = ref<QuestionAuditItem[]>([])
const total = ref(0)
const loading = ref(false)
const pager = reactive({ pageNum: 1, pageSize: 10 })
const auditStatus = ref<number | undefined>(undefined)

const loadList = async () => {
  loading.value = true
  try {
    const page = await listQuestionAudits(
      pager.pageNum,
      pager.pageSize,
      auditStatus.value,
    )
    listRef.value = page.list ?? []
    total.value = page.total ?? 0
  } catch {
    // 错误统一由 http 拦截器 ElMessage 提示，这里仅停止 loading
  } finally {
    loading.value = false
  }
}

const onFilterChange = (v?: number) => {
  auditStatus.value = v
  pager.pageNum = 1
  loadList()
}

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

// ---------- 详情弹窗 ----------
const detailVisible = ref(false)
const detailLoading = ref(false)
const detail = ref<QuestionAuditDetail | null>(null)

const openDetail = async (questionId: number) => {
  detailVisible.value = true
  detailLoading.value = true
  detail.value = null
  try {
    detail.value = await getQuestionAuditDetail(questionId)
  } catch {
    detailVisible.value = false
  } finally {
    detailLoading.value = false
  }
}

// ---------- 通过 / 驳回 ----------
const handleApprove = async (item: QuestionAuditItem) => {
  try {
    await ElMessageBox.confirm(
      `确认通过题目「${item.title}」的审核？`,
      '通过审核',
      { confirmButtonText: '通过', cancelButtonText: '取消', type: 'warning' },
    )
  } catch {
    return // 用户取消
  }
  try {
    await approveQuestion(item.questionId)
    ElMessage.success('已通过审核')
    await loadList()
  } catch {
    // 业务失败已由 http 拦截器提示
  }
}

const handleReject = async (item: QuestionAuditItem) => {
  let reason: string
  try {
    const { value } = await ElMessageBox.prompt(
      `请输入驳回题目「${item.title}」的原因`,
      '驳回审核',
      {
        confirmButtonText: '驳回',
        cancelButtonText: '取消',
        inputType: 'textarea',
        inputPlaceholder: '请填写驳回原因',
        inputValidator: (val) => {
          if (!val || !val.trim()) return '驳回原因不能为空'
          return true
        },
        inputErrorMessage: '请填写驳回原因',
      },
    )
    reason = value.trim()
  } catch {
    return // 用户取消
  }
  try {
    await rejectQuestion(item.questionId, { reason })
    ElMessage.success('已驳回')
    await loadList()
  } catch {
    // 业务失败已由 http 拦截器提示
  }
}

// 选项序号字母（A、B、C…）
const letter = (idx: number) => String.fromCharCode(65 + idx)

const handlerSizeChange = () => {
  pager.pageNum = 1
  loadList()
}

onMounted(loadList)
</script>

<template>
  <main class="admin-page">
    <section class="surface-card audit-panel">
      <div class="panel-toolbar">
        <AuditStatusFilter :model-value="auditStatus" @update:model-value="onFilterChange" />
        <span class="panel-total">共 {{ total }} 条</span>
      </div>
      <el-table v-loading="loading" :data="listRef" stripe>
        <template #empty>
          <div class="empty-tip">暂无题库记录</div>
        </template>
        <el-table-column prop="questionType" label="题型" width="116" show-overflow-tooltip />
        <el-table-column prop="department" label="科室" width="140" />
        <el-table-column prop="knowledgeTag" label="知识点" width="160">
          <template #default="{ row }">
            {{ row.knowledgeTag || '-' }}
          </template>
        </el-table-column>
        <el-table-column prop="title" label="题干" min-width="200" show-overflow-tooltip />
        <el-table-column label="难度" width="90">
          <template #default="{ row }">
            <el-tag effect="plain">{{ row.difficulty }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="submitterName" label="提交教师" width="120" />
        <el-table-column label="审核状态" width="110">
          <template #default="{ row }">
            <el-tag :type="auditStatusMap(row.auditStatus).type" effect="plain">
              {{ auditStatusMap(row.auditStatus).text }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="createdAt" label="提交时间" width="160" :formatter="tableDateTime" />
        <el-table-column label="操作" width="190" fixed="right">
          <template #default="{ row }">
            <el-button
              size="small"
              type="primary"
              link
              @click="openDetail(row.questionId)"
            >
              查看详情
            </el-button>
            <template v-if="row.auditStatus === 1">
              <el-button
                size="small"
                type="success"
                link
                @click="handleApprove(row)"
              >
                通过
              </el-button>
              <el-button
                size="small"
                type="danger"
                plain
                @click="handleReject(row)"
              >
                驳回
              </el-button>
            </template>
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
      title="题库审核详情"
      width="640px"
      :close-on-click-modal="false"
    >
      <div v-loading="detailLoading" class="detail-body">
        <template v-if="detail">
          <div class="detail-section">
            <span class="detail-meta">
              题型：{{ detail.questionType }} · 科室：{{ detail.department || '-' }}
            </span>
            <span class="detail-meta">
              知识点：{{ detail.knowledgeTag || '-' }} · 难度：{{ detail.difficulty }}
            </span>
          </div>

          <h3 class="detail-title">题干</h3>
          <p class="detail-text">{{ detail.title }}</p>

          <template v-if="detail.options && detail.options.length">
            <h3 class="detail-title">选项</h3>
            <ol class="option-list">
              <li v-for="(opt, idx) in detail.options" :key="idx">
                <span class="option-letter">{{ letter(idx) }}</span>
                <span>{{ opt }}</span>
              </li>
            </ol>
          </template>

          <h3 class="detail-title">标准答案</h3>
          <p class="detail-text answer">{{ detail.answer }}</p>

          <h3 class="detail-title">答案解析</h3>
          <p class="detail-text">{{ detail.explanation || '暂无解析' }}</p>

          <p v-if="detail.rejectReason" class="detail-reject">
            驳回原因：{{ detail.rejectReason }}
          </p>
        </template>
      </div>
    </el-dialog>
  </main>
</template>

<style scoped>
.audit-panel {
  padding: 12px;
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

.detail-body {
  min-height: 120px;
}

.detail-section {
  display: flex;
  flex-wrap: wrap;
  gap: 8px 16px;
  padding-bottom: 12px;
  margin-bottom: 8px;
  border-bottom: 1px solid var(--zy-line);
}

.detail-meta {
  color: var(--zy-muted);
  font-size: 13px;
  font-weight: 800;
}

.detail-title {
  margin: 16px 0 6px;
  color: var(--zy-ink);
  font-size: 14px;
  font-weight: 800;
}

.detail-title:first-of-type {
  margin-top: 4px;
}

.detail-text {
  margin: 0;
  color: var(--zy-ink);
  line-height: 1.6;
}

.detail-text.answer {
  font-weight: 800;
}

.option-list {
  margin: 0;
  padding: 0;
  list-style: none;
}

.option-list li {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  padding: 6px 0;
  color: var(--zy-ink);
  line-height: 1.6;
}

.option-letter {
  flex: none;
  font-weight: 800;
}

.detail-reject {
  margin: 16px 0 0;
  padding: 10px 12px;
  border-left: 3px solid var(--zy-danger);
  background: var(--zy-surface-soft);
  color: var(--zy-danger);
  font-size: 13px;
}
</style>