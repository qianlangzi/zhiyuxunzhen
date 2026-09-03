<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  deleteRuntime,
  listRuntime,
  saveRuntime,
  type RuntimeItem,
  type RuntimePayload,
} from '../../api/aiConfig'

// ---------- 筛选 ----------
const keyFilter = ref('')

// ---------- 列表 ----------
const list = ref<RuntimeItem[]>([])
const total = ref(0)
const loading = ref(false)
const pager = reactive({ pageNum: 1, pageSize: 10 })

const loadList = async () => {
  loading.value = true
  try {
    const page = await listRuntime(
      pager.pageNum,
      pager.pageSize,
      keyFilter.value.trim() || undefined,
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

// ---------- 编辑 / 新增 ----------
const dialogVisible = ref(false)
const saving = ref(false)
const editingId = ref<number | null>(null)
const isNew = ref(false)

const form = reactive<RuntimePayload>({
  configKey: '',
  configName: '',
  description: '',
  configType: 'number',
  value: '',
  defaultValue: '',
  min: '',
  max: '',
  step: '',
})

const typeOptions = [
  { value: 'number', label: '整数' },
  { value: 'float', label: '浮点' },
  { value: 'switch', label: '开关' },
  { value: 'text', label: '文本' },
]

const isSwitch = computed(() => form.configType === 'switch')
const isNumeric = computed(
  () => form.configType === 'number' || form.configType === 'float',
)

const openEdit = (item: RuntimeItem) => {
  editingId.value = item.id
  isNew.value = false
  Object.assign(form, {
    configKey: item.configKey,
    configName: item.configName,
    description: item.description ?? '',
    configType: item.configType,
    value: item.value,
    defaultValue: item.defaultValue ?? '',
    min: item.min ?? '',
    max: item.max ?? '',
    step: item.step ?? '',
  })
  dialogVisible.value = true
}

const openCreate = () => {
  editingId.value = null
  isNew.value = true
  Object.assign(form, {
    configKey: '',
    configName: '',
    description: '',
    configType: 'number',
    value: '',
    defaultValue: '',
    min: '',
    max: '',
    step: '',
  })
  dialogVisible.value = true
}

const handleSwitchChange = (val: boolean) => {
  form.value = String(val)
}

const handleSave = async () => {
  if (!form.configKey.trim()) return ElMessage.warning('请填写配置键')
  if (!form.configName.trim()) return ElMessage.warning('请填写显示名称')
  if (form.value === '' || form.value == null) return ElMessage.warning('请填写配置值')

  saving.value = true
  try {
    const payload: RuntimePayload = {
      ...form,
      configKey: form.configKey.trim(),
      configName: form.configName.trim(),
      description: (form.description ?? '').trim() || undefined,
      defaultValue: (form.defaultValue ?? '').trim() || undefined,
      min: (form.min ?? '').trim() || undefined,
      max: (form.max ?? '').trim() || undefined,
      step: (form.step ?? '').trim() || undefined,
    }
    await saveRuntime(payload)
    ElMessage.success('已保存')
    dialogVisible.value = false
    await loadList()
  } catch {
    // 业务失败由 http 拦截器提示
  } finally {
    saving.value = false
  }
}

const handleReset = async (item: RuntimeItem) => {
  if (!item.defaultValue) return ElMessage.info('该参数未设置默认值')
  try {
    await saveRuntime({
      configKey: item.configKey,
      configName: item.configName,
      description: item.description ?? undefined,
      configType: item.configType,
      value: item.defaultValue,
      defaultValue: item.defaultValue ?? undefined,
      min: item.min ?? undefined,
      max: item.max ?? undefined,
      step: item.step ?? undefined,
    })
    ElMessage.success('已恢复默认值')
    await loadList()
  } catch {
    // 业务失败由 http 拦截器提示
  }
}

const handleDelete = async (item: RuntimeItem) => {
  try {
    await ElMessageBox.confirm(
      `确认删除运行参数「${item.configName}」（${item.configKey}）？\n删除后 AI 中台将恢复该键的内置默认值。`,
      '删除运行参数',
      { confirmButtonText: '删除', cancelButtonText: '取消', type: 'error' },
    )
  } catch {
    return
  }
  try {
    await deleteRuntime(item.id)
    ElMessage.success('已删除')
    await loadList()
  } catch {
    // 业务失败由 http 拦截器提示
  }
}

// ---------- 展示 ----------
const typeLabel = (t: string) => typeOptions.find((o) => o.value === t)?.label ?? t
const displayValue = (item: RuntimeItem) =>
  item.configType === 'switch' ? (item.value === 'true' ? '开' : '关') : item.value

onMounted(loadList)
</script>

<template>
  <main class="admin-page">
    <section class="admin-page-head">
      <div>
        <span>RAG 运行参数</span>
        <h1>检索 · 改写 · 迭代 · 图述 运行期热改</h1>
      </div>
      <el-button type="primary" round @click="openCreate">
        <el-icon style="margin-right: 4px"><Plus /></el-icon>新增参数
      </el-button>
    </section>

    <!-- 热生效说明 -->
    <section class="surface-card hot-tip">
      <el-icon class="hot-icon"><Lightning /></el-icon>
      <div>
        <strong>热生效机制</strong>
        <p>
          键值型配置 storage 后，AI 中台周期拉取并覆盖运行期值（检索片段长度、向量并发、
          BM25 规模、查询改写 / 迭代检索 / 图述开关与阈值）。删除某键即恢复该键内置默认，
          幂等且可回滚。保存后请到“运行态”点击“立即应用配置”并核验生效版本。
        </p>
      </div>
    </section>

    <!-- 筛选 -->
    <section class="surface-card filter-bar">
      <el-input
        v-model="keyFilter"
        placeholder="按配置键模糊过滤，如 citation"
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
          <div class="empty-tip">暂无运行参数，点击右上角「新增参数」添加</div>
        </template>
        <el-table-column prop="configKey" label="配置键" width="210">
          <template #default="{ row }"><code class="mono">{{ row.configKey }}</code></template>
        </el-table-column>
        <el-table-column prop="configName" label="名称" width="170">
          <template #default="{ row }"><span class="name">{{ row.configName }}</span></template>
        </el-table-column>
        <el-table-column label="类型" width="80">
          <template #default="{ row }">
            <el-tag effect="plain" size="small">{{ typeLabel(row.configType) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="当前值" width="100">
          <template #default="{ row }">
            <el-switch
              v-if="row.configType === 'switch'"
              :model-value="row.value === 'true'"
              disabled
              inline-prompt
              active-text="开"
              inactive-text="关"
            />
            <span v-else class="val">{{ displayValue(row) }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="description" label="说明" min-width="240" show-overflow-tooltip>
          <template #default="{ row }">
            <span class="desc">{{ row.description || '-' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="210" fixed="right">
          <template #default="{ row }">
            <div class="op-row">
              <el-button size="small" link @click="openEdit(row)">编辑</el-button>
              <el-button
                v-if="row.defaultValue != null && row.value !== row.defaultValue"
                size="small"
                link
                @click="handleReset(row)"
              >
                恢复默认
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
      :title="isNew ? '新增运行参数' : '编辑运行参数'"
      width="600px"
      :close-on-click-modal="false"
    >
      <el-form label-width="100px" label-position="top">
        <div class="form-grid">
          <el-form-item label="配置键" required>
            <el-input v-model="form.configKey" placeholder="与 AI 中台运行参数对齐，如 citation_max_chars" :disabled="!isNew" />
          </el-form-item>
          <el-form-item label="显示名称" required>
            <el-input v-model="form.configName" placeholder="如：引文片段最大字符" />
          </el-form-item>
        </div>

        <div class="form-grid">
          <el-form-item label="参数类型">
            <el-select v-model="form.configType" style="width: 100%">
              <el-option
                v-for="opt in typeOptions"
                :key="opt.value"
                :value="opt.value"
                :label="opt.label"
              />
            </el-select>
          </el-form-item>
          <el-form-item label="配置值" required>
            <el-switch
              v-if="isSwitch"
              :model-value="form.value === 'true'"
              inline-prompt
              active-text="开"
              inactive-text="关"
              @change="handleSwitchChange"
            />
            <el-input-number
              v-else-if="isNumeric"
              v-model="form.value"
              :min="form.min ? Number(form.min) : undefined"
              :max="form.max ? Number(form.max) : undefined"
              :step="form.step ? Number(form.step) : 1"
              :precision="form.configType === 'float' ? 2 : 0"
              controls-position="right"
              style="width: 100%"
            />
            <el-input v-else v-model="form.value" placeholder="文本配置值" />
          </el-form-item>
        </div>

        <div class="form-grid">
          <el-form-item label="默认值">
            <el-input v-model="form.defaultValue" placeholder="恢复默认用" />
          </el-form-item>
          <el-form-item label="说明">
            <el-input v-model="form.description" placeholder="用途说明（可选）" />
          </el-form-item>
        </div>

        <div class="form-grid" v-if="isNumeric">
          <el-form-item label="最小值">
            <el-input v-model="form.min" placeholder="如 0" />
          </el-form-item>
          <el-form-item label="最大值">
            <el-input v-model="form.max" placeholder="如 8000" />
          </el-form-item>
          <el-form-item label="步长">
            <el-input v-model="form.step" placeholder="如 1 或 0.01" />
          </el-form-item>
        </div>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="handleSave">保存</el-button>
      </template>
    </el-dialog>
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

.val {
  color: var(--zy-ink);
  font-weight: 800;
  font-size: 13px;
}

.desc {
  color: var(--zy-muted);
  font-size: 12px;
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
</style>
