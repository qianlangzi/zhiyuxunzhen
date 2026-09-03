<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  batchFreeze,
  batchUnfreeze,
  changeUserRole,
  createAuditor,
  freezeUser,
  getUserStats,
  importStudents,
  listUsers,
  resetPassword,
  unfreezeUser,
  type AdminUserItem,
  type AdminUserStats,
  type ImportResult,
} from '../api/user'

// ---------- 统计 ----------
const stats = ref<AdminUserStats | null>(null)
const statsLoading = ref(false)

async function loadStats(): Promise<void> {
  statsLoading.value = true
  try {
    stats.value = await getUserStats()
  } catch {
    // 错误由 http 拦截器统一提示
  } finally {
    statsLoading.value = false
  }
}

const statCards = computed(() => {
  const s = stats.value
  if (!s) return []
  return [
    { label: '用户总数', value: s.totalUsers, icon: 'User', tone: 'brand' },
    { label: '学生', value: s.studentCount, icon: 'Avatar', tone: 'info' },
    { label: '教师', value: s.teacherCount, icon: 'Suitcase', tone: 'success' },
    { label: '冻结账号', value: s.frozenCount, icon: 'Lock', tone: 'danger' },
    { label: '待审教师', value: s.pendingTeacherCount, icon: 'Stamp', tone: 'warning' },
    { label: '今日新增', value: s.todayNewUsers, icon: 'Plus', tone: 'brand' },
  ]
})

// ---------- 列表 ----------
const ROLE_OPTIONS = [
  { value: 0, label: '学生' },
  { value: 1, label: '教师' },
  { value: 2, label: '教学秘书' },
  { value: 3, label: '教研室主任' },
  { value: 4, label: '超级管理员' },
  { value: 5, label: '运维' },
  { value: 6, label: '审核员' },
]

const filters = reactive<{ role?: number; status?: number; keyword: string }>({
  keyword: '',
})
const list = ref<AdminUserItem[]>([])
const total = ref(0)
const loading = ref(false)
const pager = reactive({ pageNum: 1, pageSize: 10 })
const selectedIds = ref<number[]>([])

async function loadList(): Promise<void> {
  loading.value = true
  try {
    const page = await listUsers(
      pager.pageNum,
      pager.pageSize,
      filters.role,
      filters.status,
      filters.keyword.trim() || undefined,
    )
    list.value = page.list ?? []
    total.value = page.total ?? 0
  } catch {
    // 错误由 http 拦截器统一提示
  } finally {
    loading.value = false
  }
}

function onSearch(): void {
  pager.pageNum = 1
  loadList()
}

function onResetFilters(): void {
  filters.role = undefined
  filters.status = undefined
  filters.keyword = ''
  onSearch()
}

function fmtTime(v: string | null): string {
  if (!v) return '—'
  return v.replace('T', ' ').slice(0, 16)
}

// ---------- 单条操作 ----------
const roleDialog = reactive({ visible: false, userId: 0, realName: '', role: 0 })

function openRoleDialog(row: AdminUserItem): void {
  roleDialog.userId = row.id
  roleDialog.realName = row.realName || row.username
  roleDialog.role = row.role ?? 0
  roleDialog.visible = true
}

async function submitRole(): Promise<void> {
  try {
    await changeUserRole(roleDialog.userId, roleDialog.role)
    ElMessage.success('角色已更新，该用户需重新登录生效')
    roleDialog.visible = false
    loadList()
  } catch {
    // 错误由 http 拦截器统一提示
  }
}

async function onToggleFreeze(row: AdminUserItem): Promise<void> {
  const freezing = row.status === 0
  try {
    await ElMessageBox.confirm(
      freezing ? `确定冻结「${row.realName || row.username}」？冻结后立即失效全部登录态。` : `确定解冻「${row.realName || row.username}」？`,
      freezing ? '冻结确认' : '解冻确认',
      { type: 'warning', confirmButtonText: '确定', cancelButtonText: '取消' },
    )
  } catch {
    return
  }
  try {
    if (freezing) {
      await freezeUser(row.id)
      ElMessage.success('已冻结')
    } else {
      await unfreezeUser(row.id)
      ElMessage.success('已解冻')
    }
    loadList()
    loadStats()
  } catch {
    // 错误由 http 拦截器统一提示
  }
}

async function onResetPassword(row: AdminUserItem): Promise<void> {
  try {
    await ElMessageBox.confirm(
      `重置「${row.realName || row.username}」的密码？将生成随机新密码并撤销其全部登录态。`,
      '重置密码',
      { type: 'warning', confirmButtonText: '重置', cancelButtonText: '取消' },
    )
  } catch {
    return
  }
  try {
    const newPassword = await resetPassword(row.id)
    await ElMessageBox.alert(
      `新密码：${newPassword}`,
      '请立即复制并分发给用户',
      { confirmButtonText: '已复制', type: 'success' },
    )
  } catch {
    // 错误由 http 拦截器统一提示
  }
}

// ---------- 批量操作 ----------
async function onBatchFreeze(): Promise<void> {
  if (!selectedIds.value.length) return
  try {
    const changed = await batchFreeze(selectedIds.value)
    ElMessage.success(`冻结成功 ${changed} 个账号（管理员/已冻结账号自动跳过）`)
    loadList()
    loadStats()
  } catch {
    // 错误由 http 拦截器统一提示
  }
}

async function onBatchUnfreeze(): Promise<void> {
  if (!selectedIds.value.length) return
  try {
    const changed = await batchUnfreeze(selectedIds.value)
    ElMessage.success(`解冻成功 ${changed} 个账号（弱密码账号自动跳过，需先重置密码）`)
    loadList()
    loadStats()
  } catch {
    // 错误由 http 拦截器统一提示
  }
}

// ---------- 开通审核员 ----------
const auditorDialog = reactive({ visible: false, username: '', realName: '', password: '' })

function openAuditorDialog(): void {
  auditorDialog.username = ''
  auditorDialog.realName = ''
  auditorDialog.password = ''
  auditorDialog.visible = true
}

async function submitAuditor(): Promise<void> {
  if (!auditorDialog.username.trim() || !auditorDialog.realName.trim()) {
    ElMessage.warning('请填写登录名与姓名')
    return
  }
  try {
    await createAuditor({
      username: auditorDialog.username.trim(),
      realName: auditorDialog.realName.trim(),
      password: auditorDialog.password || undefined,
    })
    ElMessage.success('审核员账号已开通')
    auditorDialog.visible = false
    loadList()
    loadStats()
  } catch {
    // 错误由 http 拦截器统一提示
  }
}

// ---------- 批量导入 ----------
const importDialog = reactive<{ visible: boolean; uploading: boolean; result: ImportResult | null }>({
  visible: false,
  uploading: false,
  result: null,
})

function openImportDialog(): void {
  importDialog.result = null
  importDialog.visible = true
}

async function onImportFile(file: File): Promise<void> {
  importDialog.uploading = true
  try {
    importDialog.result = await importStudents(file)
    ElMessage.success(`导入完成：成功 ${importDialog.result.successCount}，失败 ${importDialog.result.failCount}`)
    loadList()
    loadStats()
  } catch {
    // 错误由 http 拦截器统一提示
  } finally {
    importDialog.uploading = false
  }
}

// ---------- 初始化 ----------
onMounted(() => {
  loadStats()
  loadList()
})
</script>

<template>
  <div class="admin-page">
    <!-- 页头 -->
    <section class="admin-page-head">
      <div>
        <span>人数管理</span>
        <h1>全平台账号一览与运营操作</h1>
      </div>
      <div class="head-actions">
        <el-button plain @click="openAuditorDialog">
          <el-icon><Plus /></el-icon>&nbsp;开通审核员
        </el-button>
        <el-button type="primary" @click="openImportDialog">
          <el-icon><Upload /></el-icon>&nbsp;批量导入学生
        </el-button>
      </div>
    </section>

    <!-- 统计卡 -->
    <div class="stat-grid">
      <div v-for="card in statCards" :key="card.label" class="adm-card stat-card">
        <div class="stat-icon" :class="`tone-${card.tone}`">
          <el-icon :size="18"><component :is="card.icon" /></el-icon>
        </div>
        <div class="stat-text">
          <span class="stat-label">{{ card.label }}</span>
          <strong class="stat-value">{{ card.value }}</strong>
        </div>
      </div>
    </div>

    <!-- 列表 -->
    <div class="adm-card">
      <div class="adm-card-head">
        <h3>账号列表</h3>
        <div class="filter-bar">
          <el-select
            v-model="filters.role"
            placeholder="全部角色"
            clearable
            style="width: 130px"
            @change="onSearch"
          >
            <el-option v-for="r in ROLE_OPTIONS" :key="r.value" :label="r.label" :value="r.value" />
          </el-select>
          <el-select
            v-model="filters.status"
            placeholder="全部状态"
            clearable
            style="width: 120px"
            @change="onSearch"
          >
            <el-option label="正常" :value="0" />
            <el-option label="已冻结" :value="1" />
          </el-select>
          <el-input
            v-model="filters.keyword"
            placeholder="用户名 / 姓名 / 学校 / 手机号"
            clearable
            style="width: 240px"
            @keyup.enter="onSearch"
            @clear="onSearch"
          />
          <el-button type="primary" plain @click="onSearch">查询</el-button>
          <el-button text @click="onResetFilters">重置</el-button>
        </div>
      </div>

      <div class="adm-card-body">
        <div v-if="selectedIds.length" class="batch-bar">
          <span>已选 {{ selectedIds.length }} 项</span>
          <el-button size="small" type="danger" plain @click="onBatchFreeze">批量冻结</el-button>
          <el-button size="small" type="success" plain @click="onBatchUnfreeze">批量解冻</el-button>
        </div>

        <el-table
          v-loading="loading"
          :data="list"
          stripe
          @selection-change="(rows: AdminUserItem[]) => (selectedIds = rows.map((r) => r.id))"
        >
          <el-table-column type="selection" width="44" />
          <el-table-column label="用户" min-width="180">
            <template #default="{ row }">
              <div class="user-cell">
                <span class="user-cell-name">{{ row.realName || row.username }}</span>
                <span class="user-cell-sub">@{{ row.username }}</span>
              </div>
            </template>
          </el-table-column>
          <el-table-column label="角色" width="110">
            <template #default="{ row }">
              <el-tag size="small" :type="row.role === 0 ? 'info' : row.role === 1 ? 'success' : 'warning'" effect="light">
                {{ row.roleName }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column label="学校 / 班级" min-width="170">
            <template #default="{ row }">
              <span v-if="row.schoolName || row.className" class="muted-cell">
                {{ [row.schoolName, row.className, row.grade].filter(Boolean).join(' · ') }}
              </span>
              <span v-else class="muted-cell">—</span>
            </template>
          </el-table-column>
          <el-table-column label="手机号" width="130">
            <template #default="{ row }">
              <span class="muted-cell">{{ row.phone || '—' }}</span>
            </template>
          </el-table-column>
          <el-table-column label="状态" width="90">
            <template #default="{ row }">
              <el-tag size="small" :type="row.status === 0 ? 'success' : 'danger'" effect="plain">
                {{ row.status === 0 ? '正常' : '已冻结' }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column label="最近登录" width="140">
            <template #default="{ row }">
              <span class="muted-cell">{{ fmtTime(row.lastLoginAt) }}</span>
            </template>
          </el-table-column>
          <el-table-column label="操作" width="230" fixed="right">
            <template #default="{ row }">
              <el-button
                v-if="row.status === 0"
                link
                type="danger"
                size="small"
                :disabled="row.role === 4 || row.role === 5"
                @click="onToggleFreeze(row)"
              >
                冻结
              </el-button>
              <el-button v-else link type="success" size="small" @click="onToggleFreeze(row)">
                解冻
              </el-button>
              <el-button
                link
                type="primary"
                size="small"
                :disabled="row.role === 4 || row.role === 5"
                @click="openRoleDialog(row)"
              >
                改角色
              </el-button>
              <el-button link type="warning" size="small" @click="onResetPassword(row)">重置密码</el-button>
            </template>
          </el-table-column>
          <template #empty>
            <el-empty description="没有匹配的账号" :image-size="80" />
          </template>
        </el-table>

        <div class="pager-wrap">
          <el-pagination
            v-model:current-page="pager.pageNum"
            v-model:page-size="pager.pageSize"
            :total="total"
            :page-sizes="[10, 20, 50]"
            layout="total, sizes, prev, pager, next"
            background
            @current-change="loadList"
            @size-change="onSearch"
          />
        </div>
      </div>
    </div>

    <!-- 改角色对话框 -->
    <el-dialog v-model="roleDialog.visible" title="修改用户角色" width="420">
      <p class="dialog-hint">目标用户：{{ roleDialog.realName }}（角色变更后需重新登录生效）</p>
      <el-select v-model="roleDialog.role" style="width: 100%">
        <el-option v-for="r in ROLE_OPTIONS.filter((x) => x.value <= 3)" :key="r.value" :label="r.label" :value="r.value" />
      </el-select>
      <template #footer>
        <el-button @click="roleDialog.visible = false">取消</el-button>
        <el-button type="primary" @click="submitRole">确定</el-button>
      </template>
    </el-dialog>

    <!-- 开通审核员 -->
    <el-dialog v-model="auditorDialog.visible" title="开通审核员账号" width="440">
      <el-form label-width="80px">
        <el-form-item label="登录名">
          <el-input v-model="auditorDialog.username" placeholder="用于登录的用户名" />
        </el-form-item>
        <el-form-item label="姓名">
          <el-input v-model="auditorDialog.realName" />
        </el-form-item>
        <el-form-item label="初始密码">
          <el-input v-model="auditorDialog.password" placeholder="留空则使用默认密码 123456（首次登录强制修改）" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="auditorDialog.visible = false">取消</el-button>
        <el-button type="primary" @click="submitAuditor">开通</el-button>
      </template>
    </el-dialog>

    <!-- 批量导入 -->
    <el-dialog v-model="importDialog.visible" title="批量导入学生账号" width="560">
      <template v-if="!importDialog.result">
        <p class="dialog-hint">
          上传 Excel 文件（.xlsx），表头需包含：用户名、姓名、班级、年级、学校。
          导入成功后系统为每个学生生成临时密码，请下载结果分发给对应学生。
        </p>
        <el-upload
          drag
          accept=".xlsx,.xls"
          :auto-upload="false"
          :show-file-list="false"
          :on-change="(f: any) => f.raw && onImportFile(f.raw)"
        >
          <el-icon :size="36" class="upload-icon"><UploadFilled /></el-icon>
          <div class="el-upload__text">拖拽文件到此处，或<em>点击选择</em></div>
          <template #tip>
            <div class="el-upload__tip">仅支持 .xlsx / .xls，单次建议不超过 500 行</div>
          </template>
        </el-upload>
        <div v-if="importDialog.uploading" class="uploading-tip">
          <el-icon class="is-loading"><Loading /></el-icon>&nbsp;正在导入…
        </div>
      </template>

      <template v-else>
        <el-result
          :icon="importDialog.result.failCount > 0 ? 'warning' : 'success'"
          :title="`成功 ${importDialog.result.successCount} 人，失败 ${importDialog.result.failCount} 人`"
        />
        <el-table v-if="importDialog.result.successes?.length" :data="importDialog.result.successes" max-height="240" size="small">
          <el-table-column prop="row" label="行号" width="70" />
          <el-table-column prop="username" label="用户名" min-width="120" />
          <el-table-column prop="tempPassword" label="临时密码" min-width="120" />
        </el-table>
        <el-table v-if="importDialog.result.failures?.length" :data="importDialog.result.failures" max-height="200" size="small">
          <el-table-column prop="row" label="行号" width="70" />
          <el-table-column prop="username" label="用户名" min-width="120" />
          <el-table-column prop="reason" label="失败原因" min-width="180" />
        </el-table>
      </template>

      <template #footer>
        <el-button v-if="!importDialog.result" @click="importDialog.visible = false">取消</el-button>
        <el-button v-else type="primary" @click="importDialog.visible = false">完成</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.head-actions {
  display: flex;
  gap: 10px;
}

/* 统计卡 */
.stat-grid {
  display: grid;
  grid-template-columns: repeat(6, minmax(0, 1fr));
  gap: 12px;
}

@media (max-width: 1100px) {
  .stat-grid {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }
}

.stat-card {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 16px;
}

.stat-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  flex: none;
  width: 40px;
  height: 40px;
  border-radius: 10px;
}

.tone-brand {
  background: var(--zy-brand-soft);
  color: var(--zy-brand-strong);
}

.tone-info {
  background: rgba(59, 130, 246, 0.12);
  color: #3b82f6;
}

.tone-success {
  background: rgba(36, 122, 90, 0.12);
  color: var(--zy-success);
}

.tone-warning {
  background: var(--zy-amber-soft);
  color: var(--zy-warning);
}

.tone-danger {
  background: rgba(194, 65, 58, 0.1);
  color: var(--zy-danger);
}

.stat-text {
  min-width: 0;
}

.stat-label {
  display: block;
  color: var(--zy-muted);
  font-size: 12.5px;
}

.stat-value {
  display: block;
  margin-top: 2px;
  color: var(--zy-ink);
  font-size: 22px;
  line-height: 1.1;
  font-variant-numeric: tabular-nums;
}

/* 筛选栏 */
.filter-bar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
}

/* 批量条 */
.batch-bar {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 12px;
  padding: 8px 12px;
  border-radius: 8px;
  background: var(--zy-brand-soft);
  color: var(--zy-brand-strong);
  font-size: 13px;
}

/* 表格单元格 */
.user-cell {
  display: flex;
  flex-direction: column;
  line-height: 1.35;
}

.user-cell-name {
  color: var(--zy-ink);
  font-weight: 600;
}

.user-cell-sub {
  color: var(--zy-soft);
  font-size: 12px;
}

.muted-cell {
  color: var(--zy-muted);
  font-size: 13px;
}

.pager-wrap {
  display: flex;
  justify-content: flex-end;
  margin-top: 14px;
}

.dialog-hint {
  margin: 0 0 12px;
  color: var(--zy-muted);
  font-size: 13px;
  line-height: 1.6;
}

.upload-icon {
  color: var(--zy-brand);
  margin-bottom: 8px;
}

.uploading-tip {
  display: flex;
  align-items: center;
  margin-top: 10px;
  color: var(--zy-muted);
  font-size: 13px;
}
</style>
