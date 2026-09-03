<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  createPrompt,
  deletePrompt,
  getPromptBaseline,
  importPromptBaseline,
  listPrompts,
  setPromptActive,
  togglePrompt,
  updatePrompt,
  type BaselineItem,
  type PromptItem,
  type PromptPayload,
} from '../../api/aiConfig'

// ---------- 筛选 ----------
const nameFilter = ref('')

// ---------- 列表 ----------
const list = ref<PromptItem[]>([])
const total = ref(0)
const loading = ref(false)
const pager = reactive({ pageNum: 1, pageSize: 10 })

const loadList = async () => {
  loading.value = true
  try {
    const page = await listPrompts(
      pager.pageNum,
      pager.pageSize,
      nameFilter.value.trim() || undefined,
    )
    list.value = page.list ?? []
    total.value = page.total ?? 0
  } catch {
    // 错误由 http 拦截器提示
  } finally {
    loading.value = false
  }
}

const onSearch = () => {
  pager.pageNum = 1
  loadList()
}

const onPageChange = () => loadList()
const onSizeChange = () => {
  pager.pageNum = 1
  loadList()
}

// ---------- 新增 / 编辑 ----------
const dialogVisible = ref(false)
const saving = ref(false)
const editingId = ref<number | null>(null)
const form = reactive<PromptPayload>({
  name: '',
  version: 'v1',
  title: '',
  description: '',
  content: '',
  status: 1,
})

const resetForm = () => {
  editingId.value = null
  Object.assign(form, {
    name: '',
    version: 'v1',
    title: '',
    description: '',
    content: '',
    status: 1,
  })
}

const openCreate = () => {
  resetForm()
  dialogVisible.value = true
}

const openEdit = (item: PromptItem) => {
  editingId.value = item.id
  Object.assign(form, {
    name: item.name,
    version: item.version ?? 'v1',
    title: item.title,
    description: item.description ?? '',
    content: item.content,
    status: item.status,
  })
  dialogVisible.value = true
}

const handleSave = async () => {
  if (!form.name.trim()) return ElMessage.warning('请填写逻辑键（如 sp / mentor）')
  if (!form.title.trim()) return ElMessage.warning('请填写显示名称')
  if (!form.content.trim()) return ElMessage.warning('请填写提示词正文')

  saving.value = true
  try {
    const payload: PromptPayload = {
      ...form,
      name: form.name.trim(),
      title: form.title.trim(),
      version: (form.version ?? '').trim() || undefined,
      description: (form.description ?? '').trim() || undefined,
    }
    if (editingId.value) {
      await updatePrompt(editingId.value, payload)
      ElMessage.success('已保存')
    } else {
      await createPrompt(payload)
      ElMessage.success('已创建')
    }
    dialogVisible.value = false
    await loadList()
  } catch {
    // 业务失败由 http 拦截器提示
  } finally {
    saving.value = false
  }
}

// ---------- 激活 / 启停 / 删除 ----------
const handleSetActive = async (item: PromptItem) => {
  try {
    await ElMessageBox.confirm(
      `将提示词「${item.title}」（${item.name}）设为当前激活版本？\n切换后请到“运行态”点击“立即应用配置”并核验生效版本。`,
      '设为激活',
      { confirmButtonText: '激活', cancelButtonText: '取消', type: 'warning' },
    )
  } catch {
    return
  }
  try {
    await setPromptActive(item.id)
    ElMessage.success('已设为激活')
    await loadList()
  } catch {
    // 业务失败由 http 拦截器提示
  }
}

const handleToggle = async (item: PromptItem) => {
  const enable = item.status !== 1
  try {
    await ElMessageBox.confirm(
      enable ? `确认启用提示词「${item.title}」？` : `确认停用提示词「${item.title}」？`,
      enable ? '启用提示词' : '停用提示词',
      { confirmButtonText: enable ? '启用' : '停用', cancelButtonText: '取消', type: 'warning' },
    )
  } catch {
    return
  }
  try {
    await togglePrompt(item.id)
    ElMessage.success(enable ? '已启用' : '已停用')
    await loadList()
  } catch {
    // 业务失败由 http 拦截器提示
  }
}

const handleDelete = async (item: PromptItem) => {
  try {
    await ElMessageBox.confirm(
      `确认删除提示词「${item.title}」？删除后不可恢复。`,
      '删除提示词',
      { confirmButtonText: '删除', cancelButtonText: '取消', type: 'error' },
    )
  } catch {
    return
  }
  try {
    await deletePrompt(item.id)
    ElMessage.success('已删除')
    await loadList()
  } catch {
    // 业务失败由 http 拦截器提示
  }
}

onMounted(loadList)

// ---------- 从内置基线导入（解决「配置在管理端不展示」） ----------
// AI 中台内置提示词默认以代码形式存在（templates.py）。未导入数据库时，
// 管理端列表为空、但 AI 实际按内置模板在运行。此功能把它「物化」进数据库后即可热改。
const baselineVisible = ref(false)
const baselineItems = ref<Array<{ name: string; title: string; description: string; content: string; checked: boolean }>>([])
const baselineLoading = ref(false)
const importing = ref(false)

const openBaseline = async () => {
  baselineVisible.value = true
  baselineLoading.value = true
  try {
    const map = await getPromptBaseline()
    baselineItems.value = Object.entries<BaselineItem>(map ?? {}).map(([name, v]) => ({
      name,
      title: v.title ?? name,
      description: v.description ?? '',
      content: v.content ?? '',
      checked: true,
    }))
  } catch {
    // 错误由 http 拦截器提示
  } finally {
    baselineLoading.value = false
  }
}

const toggleAll = (check: boolean) => baselineItems.value.forEach((i) => (i.checked = check))

const doImport = async () => {
  const names = baselineItems.value.filter((i) => i.checked).map((i) => i.name)
  if (!names.length) return ElMessage.warning('请先勾选要导入的提示词')
  importing.value = true
  try {
    const n = await importPromptBaseline(names)
    ElMessage.success(`已导入 ${n} 条内置提示词（已存在的自动跳过）`)
    baselineVisible.value = false
    await loadList()
  } catch {
    // 错误由 http 拦截器提示
  } finally {
    importing.value = false
  }
}
</script>

<template>
  <main class="admin-page">
    <section class="admin-page-head">
      <div>
        <span>提示词管理</span>
        <h1>各 Agent 的 system prompt 热改</h1>
      </div>
      <div class="head-actions">
        <el-button round @click="openBaseline">
          <el-icon style="margin-right: 4px"><Download /></el-icon>从内置基线导入
        </el-button>
        <el-button type="primary" round @click="openCreate">
          <el-icon style="margin-right: 4px"><Plus /></el-icon>新增提示词
        </el-button>
      </div>
    </section>

    <!-- 热生效说明 -->
    <section class="surface-card hot-tip">
      <el-icon class="hot-icon"><Lightning /></el-icon>
      <div>
        <strong>热生效机制</strong>
        <p>
          提示词正文文本存入数据库，支持 <code>{占位符}</code> 注入运行时变量（如病例、阶段）。
          逻辑键（name）与 AI 中台内置模板名对齐：未配置时 AI 中台回退内置模板，平滑迁移。
          将某版本设为「激活」后，可到“运行态”立即应用并核验，无需重启服务。
        </p>
      </div>
    </section>

    <!-- 筛选 -->
    <section class="surface-card filter-bar">
      <el-input
        v-model="nameFilter"
        placeholder="按逻辑键过滤，如 sp / mentor"
        clearable
        style="max-width: 280px"
        @keyup.enter="onSearch"
        @clear="onSearch"
      />
      <el-button @click="onSearch">查询</el-button>
    </section>

    <section class="surface-card audit-panel">
      <el-table v-loading="loading" :data="list" stripe>
        <template #empty>
          <div class="empty-tip">
            <p>暂无已入库提示词。当前 AI 仍按内置模板运行。</p>
            <p>点击右上角「从内置基线导入」，把内置提示词物化进数据库后即可在线热改。</p>
          </div>
        </template>
        <el-table-column prop="name" label="逻辑键" width="140">
          <template #default="{ row }">
            <code class="mono">{{ row.name }}</code>
            <el-tag v-if="row.isActive" type="success" size="small" effect="dark" class="active-tag">
              激活
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="title" label="显示名称" width="160">
          <template #default="{ row }">
            <span class="name">{{ row.title }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="version" label="版本" width="90">
          <template #default="{ row }">
            <el-tag effect="plain">{{ row.version || 'v1' }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="content" label="提示词正文概要" min-width="260" show-overflow-tooltip>
          <template #default="{ row }">
            <span class="content-preview">{{ row.content }}</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="90">
          <template #default="{ row }">
            <el-tag :type="row.status === 1 ? 'success' : 'info'" effect="plain">
              {{ row.status === 1 ? '启用' : '停用' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="240" fixed="right">
          <template #default="{ row }">
            <div class="op-row">
              <el-button
                v-if="!row.isActive"
                size="small"
                type="primary"
                link
                :disabled="row.status !== 1"
                @click="handleSetActive(row)"
              >
                设激活
              </el-button>
              <el-button size="small" link @click="openEdit(row)">编辑</el-button>
              <el-button
                size="small"
                link
                :type="row.status === 1 ? 'warning' : 'success'"
                @click="handleToggle(row)"
              >
                {{ row.status === 1 ? '停用' : '启用' }}
              </el-button>
              <el-button size="small" link type="danger" @click="handleDelete(row)">删除</el-button>
            </div>
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
    </section>

    <!-- 新增/编辑弹窗 -->
    <el-dialog
      v-model="dialogVisible"
      :title="editingId ? '编辑提示词' : '新增提示词'"
      width="680px"
      :close-on-click-modal="false"
    >
      <el-form label-width="100px" label-position="top">
        <div class="form-grid">
          <el-form-item label="逻辑键" required>
            <el-input v-model="form.name" placeholder="如：sp / mentor / evaluator" />
          </el-form-item>
          <el-form-item label="版本号">
            <el-input v-model="form.version" placeholder="如 v1 / v2" />
          </el-form-item>
        </div>

        <div class="form-grid">
          <el-form-item label="显示名称" required>
            <el-input v-model="form.title" placeholder="便于管理端识别，如：标准病人对话" />
          </el-form-item>
          <el-form-item label="状态">
            <el-radio-group v-model="form.status">
              <el-radio :value="1">启用</el-radio>
              <el-radio :value="0">停用</el-radio>
            </el-radio-group>
          </el-form-item>
        </div>

        <el-form-item label="用途说明">
          <el-input v-model="form.description" type="textarea" :rows="2" placeholder="此提示词用于哪个场景（可选）" />
        </el-form-item>

        <el-form-item label="提示词正文" required>
          <el-input
            v-model="form.content"
            type="textarea"
            :rows="8"
            placeholder="支持 {占位符} 注入运行时变量，如 {case_context}、{stage}"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="handleSave">保存</el-button>
      </template>
    </el-dialog>

    <!-- 内置基线导入抽屉 -->
    <el-drawer v-model="baselineVisible" title="从内置基线导入提示词" size="520px">
      <p class="base-desc">
        左侧为 AI 中台内置提示词（代码中的默认模板）。导入后将写入数据库
        <code>ai_prompt</code>，即可在线编辑并「设激活」热生效。<strong>已存在的逻辑键会自动跳过</strong>，不会覆盖你已修改的内容。
      </p>
      <div class="base-op">
        <span>共 {{ baselineItems.length }} 项</span>
        <div>
          <el-button link size="small" @click="toggleAll(true)">全选</el-button>
          <el-button link size="small" @click="toggleAll(false)">清空</el-button>
        </div>
      </div>
      <div v-loading="baselineLoading" class="base-list">
        <el-checkbox-group :model-value="baselineItems.filter((i) => i.checked).map((i) => i.name)">
          <div v-for="item in baselineItems" :key="item.name" class="base-item">
            <el-checkbox :value="item.name" @change="(v: boolean | string | number) => (item.checked = !!v)" />
            <div class="base-item-body">
              <div class="base-item-head">
                <code class="mono">{{ item.name }}</code>
                <span>{{ item.title }}</span>
              </div>
              <div class="base-item-desc">{{ item.description }}</div>
            </div>
          </div>
        </el-checkbox-group>
      </div>
      <template #footer>
        <el-button @click="baselineVisible = false">取消</el-button>
        <el-button type="primary" :loading="importing" @click="doImport">导入选中项</el-button>
      </template>
    </el-drawer>
  </main>
</template>

<style scoped>
.admin-page-head {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 16px;
}

.hot-tip {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 14px 16px;
  margin-bottom: 14px;
  border: 1px solid var(--zy-brand-soft);
  background: linear-gradient(135deg, var(--zy-brand-soft), #fff);
}

.hot-icon {
  flex: none;
  margin-top: 2px;
  color: var(--zy-brand-strong);
  font-size: 18px;
}

.hot-tip strong {
  color: var(--zy-ink);
  font-size: 14px;
  font-weight: 800;
}

.hot-tip p {
  margin: 4px 0 0;
  color: var(--zy-muted);
  font-size: 13px;
  line-height: 1.6;
}

.hot-tip code {
  padding: 1px 4px;
  border-radius: 4px;
  background: var(--zy-brand-soft);
  color: var(--zy-brand-strong);
}

.filter-bar {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px 14px;
  margin-bottom: 14px;
}

.audit-panel {
  padding: 16px;
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

.mono {
  padding: 2px 6px;
  border-radius: 6px;
  background: var(--zy-surface-soft);
  color: var(--zy-ink);
  font-size: 12px;
}

.name {
  color: var(--zy-ink);
  font-weight: 800;
}

.active-tag {
  margin-left: 8px;
}

.content-preview {
  display: block;
  color: var(--zy-muted);
  font-size: 12px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.op-row {
  display: flex;
  align-items: center;
  gap: 2px;
  flex-wrap: wrap;
}

.form-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0 16px;
}

.head-actions {
  display: flex;
  align-items: center;
  gap: 8px;
}

.base-desc {
  color: var(--zy-muted);
  font-size: 13px;
  line-height: 1.7;
}

.base-desc code {
  padding: 1px 4px;
  border-radius: 4px;
  background: var(--zy-surface-soft);
  color: var(--zy-ink);
}

.base-op {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin: 12px 0 8px;
  color: var(--zy-muted);
  font-size: 13px;
}

.base-list {
  max-height: 56vh;
  overflow-y: auto;
}

.base-item {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  padding: 10px 12px;
  border: 1px solid var(--zy-line);
  border-radius: 12px;
  margin-bottom: 8px;
}

.base-item-head {
  display: flex;
  align-items: center;
  gap: 8px;
}

.base-item-head span {
  color: var(--zy-ink);
  font-weight: 800;
}

.base-item-desc {
  margin-top: 4px;
  color: var(--zy-muted);
  font-size: 12px;
  line-height: 1.5;
}
</style>
