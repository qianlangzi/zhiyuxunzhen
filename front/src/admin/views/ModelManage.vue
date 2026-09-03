<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  CAPABILITY_LABELS,
  createModel,
  deleteModel,
  listModels,
  setModelActive,
  testModel,
  toggleModel,
  updateModel,
  type ModelItem,
  type ModelPayload,
} from '../api/model'

// ---------- 筛选 ----------
const activeCap = ref<string>('') // '' = 全部
const capOptions = [
  { value: '', label: '全部能力' },
  { value: 'LLM', label: '大模型对话' },
  { value: 'VISION', label: '视觉理解' },
  { value: 'EMBEDDING', label: '文本向量' },
  { value: 'EMBEDDING_MULTI', label: '多模态向量' },
]

// ---------- 列表 ----------
const list = ref<ModelItem[]>([])
const total = ref(0)
const loading = ref(false)
const pager = reactive({ pageNum: 1, pageSize: 10 })

const loadList = async () => {
  loading.value = true
  try {
    const page = await listModels(
      pager.pageNum,
      pager.pageSize,
      activeCap.value || undefined,
    )
    list.value = page.list ?? []
    total.value = page.total ?? 0
  } catch {
    // 错误由 http 拦截器提示
  } finally {
    loading.value = false
  }
}

const switchCap = (cap: string) => {
  activeCap.value = cap
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
const form = reactive<ModelPayload>({
  name: '',
  provider: '',
  capability: 'LLM',
  baseUrl: '',
  apiKey: '',
  model: '',
  dimension: 1024,
  timeoutSeconds: 30,
  maxTokens: 2048,
  temperature: 0.7,
  status: 1,
  description: '',
})
// 编辑时是否已有 apiKey（用于占位提示）
const hasApiKey = ref(false)

const resetForm = () => {
  editingId.value = null
  hasApiKey.value = false
  Object.assign(form, {
    name: '',
    provider: '',
    capability: 'LLM',
    baseUrl: '',
    apiKey: '',
    model: '',
    dimension: 1024,
    timeoutSeconds: 30,
    maxTokens: 2048,
    temperature: 0.7,
    status: 1,
    description: '',
  })
}

const openCreate = () => {
  resetForm()
  dialogVisible.value = true
}

const openEdit = (item: ModelItem) => {
  editingId.value = item.id
  hasApiKey.value = item.hasApiKey
  Object.assign(form, {
    name: item.name,
    provider: item.provider ?? '',
    capability: item.capability,
    baseUrl: item.baseUrl,
    apiKey: '', // 不回显密钥，留空=保留
    model: item.model,
    dimension: item.dimension ?? 1024,
    timeoutSeconds: item.timeoutSeconds ?? 30,
    maxTokens: item.maxTokens ?? 2048,
    temperature: item.temperature ?? 0.7,
    status: item.status,
    description: item.description ?? '',
  })
  dialogVisible.value = true
}

const handleSave = async () => {
  // 轻量校验
  if (!form.name.trim()) return ElMessage.warning('请填写模型名称')
  if (!form.baseUrl.trim()) return ElMessage.warning('请填写接口地址')
  if (!form.model.trim()) return ElMessage.warning('请填写模型名')

  saving.value = true
  try {
    const apiKey = (form.apiKey ?? '').trim() || undefined
    const provider = (form.provider ?? '').trim() || undefined
    const description = (form.description ?? '').trim() || undefined
    const payload: ModelPayload = {
      ...form,
      apiKey,
      provider,
      description,
      // 非向量能力清空 dimension
      dimension:
        form.capability === 'EMBEDDING' || form.capability === 'EMBEDDING_MULTI'
          ? form.dimension
          : null,
    }
    if (editingId.value) {
      await updateModel(editingId.value, payload)
      ElMessage.success('已保存')
    } else {
      await createModel(payload)
      ElMessage.success('已创建')
    }
    dialogVisible.value = false
    await loadList()
    // 引导闭环：模型配置保存后需到「AI 配置中心-运行态」点击「立即应用配置」才会热生效
    ElMessage.info('模型已保存，生效需到 AI 配置中心「运行态」点击「立即应用配置」并核验快照')
  } catch {
    // 业务失败由 http 拦截器提示
  } finally {
    saving.value = false
  }
}

// ---------- 激活 / 启停 / 删除 / 测试 ----------
const handleSetActive = async (item: ModelItem) => {
  try {
    await ElMessageBox.confirm(
      `将模型「${item.name}」设为${CAPABILITY_LABELS[item.capability] || item.capability}的当前激活项？\n激活后请到 AI 配置中心“运行态”点击“立即应用配置”并核验快照版本。`,
      '设为激活',
      { confirmButtonText: '激活', cancelButtonText: '取消', type: 'warning' },
    )
  } catch {
    return
  }
  try {
    await setModelActive(item.id)
    ElMessage.success('已设为激活')
    await loadList()
  } catch {
    // 业务失败由 http 拦截器提示
  }
}

const handleToggle = async (item: ModelItem) => {
  const enable = item.status !== 1
  try {
    await ElMessageBox.confirm(
      enable ? `确认启用模型「${item.name}」？` : `确认停用模型「${item.name}」？`,
      enable ? '启用模型' : '停用模型',
      { confirmButtonText: enable ? '启用' : '停用', cancelButtonText: '取消', type: 'warning' },
    )
  } catch {
    return
  }
  try {
    await toggleModel(item.id)
    ElMessage.success(enable ? '已启用' : '已停用')
    await loadList()
  } catch {
    // 业务失败由 http 拦截器提示
  }
}

const handleDelete = async (item: ModelItem) => {
  try {
    await ElMessageBox.confirm(
      `确认删除模型「${item.name}」？删除后不可恢复。`,
      '删除模型',
      { confirmButtonText: '删除', cancelButtonText: '取消', type: 'error' },
    )
  } catch {
    return
  }
  try {
    await deleteModel(item.id)
    ElMessage.success('已删除')
    await loadList()
  } catch {
    // 业务失败由 http 拦截器提示
  }
}

const testingId = ref<number | null>(null)
const handleTest = async (item: ModelItem) => {
  testingId.value = item.id
  try {
    const result = await testModel(item.id)
    if (result.ok) {
      ElMessage.success(`连通正常（耗时 ${result.latencyMs ?? '-'} ms）`)
    } else {
      ElMessage.warning(result.message || '连接失败')
    }
  } catch {
    // 错误由 http 拦截器提示
  } finally {
    testingId.value = null
  }
}

// ---------- 展示工具 ----------
const isVectorCap = (cap: string) => cap === 'EMBEDDING' || cap === 'EMBEDDING_MULTI'
const capLabel = (cap: string) => CAPABILITY_LABELS[cap] ?? cap

onMounted(loadList)
</script>

<template>
  <main class="admin-page">
    <section class="admin-page-head">
      <div>
        <span>模型管理</span>
        <h1>AI 模型供应商统一管理</h1>
      </div>
      <el-button type="primary" round @click="openCreate">
        <el-icon style="margin-right: 4px"><Plus /></el-icon>新增模型
      </el-button>
    </section>

    <!-- 热生效说明 -->
    <section class="surface-card hot-tip">
      <el-icon class="hot-icon"><Lightning /></el-icon>
      <div>
        <strong>热生效机制</strong>
        <p>
          模型配置存入数据库。管理端将某模型设为「激活」后，AI 中台会自动拉取最新配置，
          教师端与学生端无需重启服务；切换后请到 AI 配置中心运行态立即应用并核验版本。
        </p>
      </div>
    </section>

    <!-- 能力筛选 -->
    <section class="surface-card filter-bar">
      <button
        v-for="opt in capOptions"
        :key="opt.value"
        class="filter-chip"
        :class="{ active: activeCap === opt.value }"
        @click="switchCap(opt.value)"
      >
        {{ opt.label }}
      </button>
    </section>

    <section class="surface-card audit-panel">
      <el-table v-loading="loading" :data="list" stripe>
        <template #empty>
          <div class="empty-tip">暂无模型配置，点击右上角「新增模型」开始</div>
        </template>
        <el-table-column prop="name" label="模型名称" min-width="140">
          <template #default="{ row }">
            <span class="model-name">{{ row.name }}</span>
            <el-tag v-if="row.isActive" type="success" size="small" effect="dark" class="active-tag">
              激活
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="provider" label="供应商" width="110">
          <template #default="{ row }">{{ row.provider || '-' }}</template>
        </el-table-column>
        <el-table-column label="能力" width="120">
          <template #default="{ row }">
            <el-tag effect="plain">{{ capLabel(row.capability) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="model" label="模型名" width="150" show-overflow-tooltip>
          <template #default="{ row }">
            <code class="model-code">{{ row.model }}</code>
          </template>
        </el-table-column>
        <el-table-column label="接口地址" min-width="180" show-overflow-tooltip>
          <template #default="{ row }">
            <code class="model-code">{{ row.baseUrl }}</code>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="90">
          <template #default="{ row }">
            <el-tag :type="row.status === 1 ? 'success' : 'info'" effect="plain">
              {{ row.status === 1 ? '启用' : '停用' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="250" fixed="right">
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
              <el-button
                size="small"
                link
                :loading="testingId === row.id"
                @click="handleTest(row)"
              >
                测试
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
              <el-button size="small" link type="danger" @click="handleDelete(row)">
                删除
              </el-button>
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
      :title="editingId ? '编辑模型' : '新增模型'"
      width="640px"
      :close-on-click-modal="false"
    >
      <el-form label-width="100px" label-position="top" class="model-form">
        <div class="form-grid">
          <el-form-item label="模型名称" required>
            <el-input v-model="form.name" placeholder="如：DeepSeek V4 Flash" />
          </el-form-item>
          <el-form-item label="供应商">
            <el-input v-model="form.provider" placeholder="如：DeepSeek / 阿里云 MaaS" />
          </el-form-item>
        </div>

        <div class="form-grid">
          <el-form-item label="能力类型" required>
            <el-select v-model="form.capability" style="width: 100%">
              <el-option
                v-for="opt in capOptions.slice(1)"
                :key="opt.value"
                :value="opt.value"
                :label="opt.label"
              />
            </el-select>
          </el-form-item>
          <el-form-item label="状态">
            <el-radio-group v-model="form.status">
              <el-radio :value="1">启用</el-radio>
              <el-radio :value="0">停用</el-radio>
            </el-radio-group>
          </el-form-item>
        </div>

        <div class="form-grid">
          <el-form-item label="模型名" required>
            <el-input v-model="form.model" placeholder="如：deepseek-v4-flash" />
          </el-form-item>
          <el-form-item label="接口地址" required>
            <el-input v-model="form.baseUrl" placeholder="OpenAI 兼容 Base URL" />
          </el-form-item>
        </div>

        <div class="form-grid">
          <el-form-item label="API Key">
            <el-input
              v-model="form.apiKey"
              type="password"
              show-password
              :placeholder="hasApiKey ? '已配置，留空则不修改' : '请输入 API Key'"
            />
          </el-form-item>
          <el-form-item label="超时（秒）">
            <el-input-number v-model="form.timeoutSeconds" :min="1" :max="300" />
          </el-form-item>
        </div>

        <div class="form-grid" v-if="isVectorCap(form.capability) || form.capability === 'LLM'">
          <el-form-item
            v-if="isVectorCap(form.capability)"
            label="向量维度"
          >
            <el-input-number v-model="form.dimension" :min="64" :max="8192" :step="128" />
          </el-form-item>
          <template v-else>
            <el-form-item label="最大 Tokens">
              <el-input-number v-model="form.maxTokens" :min="1" :max="32768" />
            </el-form-item>
            <el-form-item label="温度">
              <el-input-number v-model="form.temperature" :min="0" :max="2" :step="0.1" />
            </el-form-item>
          </template>
        </div>

        <el-form-item label="备注">
          <el-input v-model="form.description" type="textarea" :rows="2" placeholder="用途说明（可选）" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="handleSave">
          保存
        </el-button>
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
  gap: 8px;
  padding: 12px 14px;
  margin-bottom: 14px;
  overflow-x: auto;
}

.filter-chip {
  flex: none;
  padding: 7px 16px;
  border: 1px solid var(--zy-line);
  border-radius: 999px;
  background: #fff;
  color: var(--zy-muted);
  font-size: 13px;
  font-weight: 800;
  cursor: pointer;
  transition: all 160ms ease;
}

.filter-chip:hover {
  border-color: var(--zy-brand-soft);
  color: var(--zy-brand-strong);
}

.filter-chip.active {
  border-color: var(--zy-brand-strong);
  background: var(--zy-brand-strong);
  color: #fff;
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

.model-name {
  color: var(--zy-ink);
  font-weight: 800;
}

.active-tag {
  margin-left: 8px;
}

.model-code {
  padding: 2px 6px;
  border-radius: 6px;
  background: var(--zy-surface-soft);
  color: var(--zy-ink);
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

.model-form :deep(.el-form-item) {
  margin-bottom: 16px;
}
</style>
