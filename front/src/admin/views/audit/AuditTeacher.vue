<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  approveTeacher,
  getTeacherAuditDetail,
  listTeacherAudits,
  rejectTeacher,
  type TeacherAuditDetail,
  type TeacherAuditItem,
} from '../../api/teacherAudit'
import { fmtDateTime, tableDateTime } from '../../utils/format'
import AuditStatusFilter from './AuditStatusFilter.vue'

const list = ref<TeacherAuditItem[]>([])
const total = ref(0)
const loading = ref(false)
const pager = reactive({ pageNum: 1, pageSize: 10 })
const auditStatus = ref<number | undefined>(undefined)

const loadList = async () => {
  loading.value = true
  try {
    const page = await listTeacherAudits(
      pager.pageNum,
      pager.pageSize,
      auditStatus.value,
    )
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
const detail = ref<TeacherAuditDetail | null>(null)

const openDetail = async (userId: number) => {
  detailVisible.value = true
  detailLoading.value = true
  detail.value = null
  try {
    detail.value = await getTeacherAuditDetail(userId)
  } catch {
    detailVisible.value = false
  } finally {
    detailLoading.value = false
  }
}

const statusText = (s?: number) => statusMap(s ?? 0).text

const accountStatusText = (s?: number) =>
  s === 1 ? '已冻结' : '正常'

const handleApprove = async (item: TeacherAuditItem) => {
  try {
    await ElMessageBox.confirm(
      `确认通过教师「${item.realName || item.username}」的资质审核？`,
      '通过审核',
      { confirmButtonText: '通过', cancelButtonText: '取消', type: 'warning' },
    )
  } catch {
    return
  }
  try {
    await approveTeacher(item.userId)
    ElMessage.success('已通过审核')
    await loadList()
  } catch {
    // 业务失败由 http 拦截器提示
  }
}

const handleReject = async (item: TeacherAuditItem) => {
  let reason: string
  try {
    const { value } = await ElMessageBox.prompt(
      `请输入驳回教师「${item.realName || item.username}」的原因`,
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
    return
  }
  try {
    await rejectTeacher(item.userId, { reason })
    ElMessage.success('已驳回')
    await loadList()
  } catch {
    // 业务失败由 http 拦截器提示
  }
}

/** 教师审核状态文案/类型（0未提交 1待审核 2通过 3驳回） */
const statusMap = (s: number) => {
  switch (s) {
    case 0:
      return { text: '未提交', type: 'info' as const }
    case 1:
      return { text: '待审核', type: 'warning' as const }
    case 2:
      return { text: '已通过', type: 'success' as const }
    default:
      return { text: '已驳回', type: 'danger' as const }
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
        <div class="empty-tip">暂无教师审核记录</div>
      </template>
      <el-table-column prop="realName" label="姓名" width="110">
        <template #default="{ row }">{{ row.realName || '-' }}</template>
      </el-table-column>
      <el-table-column prop="username" label="账号" width="120" />
      <el-table-column prop="department" label="科室" min-width="120">
        <template #default="{ row }">{{ row.department || '-' }}</template>
      </el-table-column>
      <el-table-column prop="certificateNo" label="证书编号" min-width="150">
        <template #default="{ row }">{{ row.certificateNo || '-' }}</template>
      </el-table-column>
      <el-table-column prop="phone" label="手机号" width="130" />
      <el-table-column label="状态" width="100">
        <template #default="{ row }">
          <el-tag :type="statusMap(row.auditStatus).type" effect="plain">
            {{ statusMap(row.auditStatus).text }}
          </el-tag>
        </template>
      </el-table-column>
      <el-table-column prop="createdAt" label="提交时间" width="160" :formatter="tableDateTime" />
      <el-table-column label="操作" width="220" fixed="right">
        <template #default="{ row }">
          <el-button size="small" type="primary" link @click="openDetail(row.userId)">
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
      title="教师资质审核详情"
      width="640px"
      :close-on-click-modal="false"
    >
      <div v-loading="detailLoading" class="detail-body">
        <template v-if="detail">
          <p class="detail-status">
            <el-tag :type="statusMap(detail.auditStatus).type" effect="plain">
              {{ statusText(detail.auditStatus) }}
            </el-tag>
            <el-tag :type="detail.status === 1 ? 'danger' : 'success'" effect="plain">
              {{ accountStatusText(detail.status) }}
            </el-tag>
          </p>

          <h3 class="detail-title">基本信息</h3>
          <div class="detail-grid">
            <span>姓名 <b>{{ detail.realName || '-' }}</b></span>
            <span>账号 <b>{{ detail.username }}</b></span>
            <span>手机号 <b>{{ detail.phone || '-' }}</b></span>
            <span>身份证 <b>{{ detail.idCard || '-' }}</b></span>
            <span>学校 <b>{{ detail.schoolName || '-' }}</b></span>
            <span>科室 <b>{{ detail.department || '-' }}</b></span>
            <span>入职年级 <b>{{ detail.grade || '-' }}</b></span>
            <span>班级 <b>{{ detail.className || '-' }}</b></span>
            <span>证书编号 <b>{{ detail.teacherCertificateNo || '-' }}</b></span>
            <span>最近登录 <b>{{ fmtDateTime(detail.lastLoginAt) }}</b></span>
            <span>注册时间 <b>{{ fmtDateTime(detail.createdAt) }}</b></span>
          </div>

          <h3 class="detail-title">资质证书</h3>
          <div v-if="detail.teacherCertificateImage" class="cert-box">
            <el-image
              :src="detail.teacherCertificateImage"
              :preview-src-list="[detail.teacherCertificateImage]"
              fit="contain"
              class="cert-img"
            />
          </div>
          <p v-else class="detail-null">未上传资质证书</p>
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

.detail-status {
  display: flex;
  gap: 8px;
  margin: 0 0 4px;
}

.detail-title {
  margin: 18px 0 8px;
  color: var(--zy-ink);
  font-size: 14px;
  font-weight: 800;
}

.detail-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 10px 16px;
}

.detail-grid span {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 8px;
  padding-bottom: 6px;
  border-bottom: 1px dashed var(--zy-line);
  color: var(--zy-muted);
  font-size: 13px;
}

.detail-grid b {
  color: var(--zy-ink);
  font-weight: 700;
  text-align: right;
}

.cert-box {
  padding: 8px;
  border: 1px solid var(--zy-line);
  border-radius: 12px;
}

.cert-img {
  width: 100%;
  max-height: 340px;
  border-radius: 8px;
}

.detail-null {
  margin: 0;
  color: var(--zy-muted);
  font-size: 13px;
}

@media (max-width: 640px) {
  .detail-grid {
    grid-template-columns: 1fr;
  }
}
</style>
