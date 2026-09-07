<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import {
  createAgent,
  deleteAgent,
  getAgentBaseline,
  importAgentBaseline,
  listAgents,
  setAgentActive,
  toggleAgent,
  updateAgent,
  type AgentItem,
  type AgentPayload,
  type BaselineItem,
} from '../../api/aiConfig'

// ---------- 筛选 ----------
const codeFilter = ref('')

// ---------- 列表 ----------
const list = ref<AgentItem[]>([])
const total = ref(0)
const loading = ref(false)
const pager = reactive({ pageNum: 1, pageSize: 10 })

const loadList = async () => {
  loading.value = true
  try {
    const page = await listAgents(
      pager.pageNum,
      pager.pageSize,
      codeFilter.value.trim() || undefined,
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
const form = reactive<AgentPayload>({
  code: '',
  name: '',
  description: '',
  promptName: '',
  promptOverride: '',
  temperature: null,
  maxTokens: null,
  toolsConfig: '',
  strategy: 'CODE',
  model: '',
  maxIterations: null,
  status: 1,
})

const resetForm = () => {
  editingId.value = null
  Object.assign(form, {
    code: '',
    name: '',
    description: '',
    promptName: '',
    promptOverride: '',
    temperature: null,
    maxTokens: null,
    toolsConfig: '',
    strategy: 'CODE',
    model: '',
    maxIterations: null,
    status: 1,
  })
}

const openCreate = () => {
  resetForm()
  dialogVisible.value = true
}

const openEdit = (item: AgentItem) => {
  editingId.value = item.id
  Object.assign(form, {
    code: item.code,
    name: item.name,
    description: item.description ?? '',
    promptName: item.promptName ?? '',
    promptOverride: item.promptOverride ?? '',
    temperature: item.temperature,
    maxTokens: item.maxTokens,
    toolsConfig: item.toolsConfig ?? '',
    strategy: item.strategy ?? 'CODE',
    model: item.model ?? '',
    maxIterations: item.maxIterations,
    status: item.status,
  })
  dialogVisible.value = true
}

const handleSave = async () => {
  if (!form.code.trim()) return ElMessage.warning('请填写 Agent 逻辑键')
  if (!form.name.trim()) return ElMessage.warning('请填写显示名称')
  if (
    form.temperature != null &&
    (form.temperature < 0 || form.temperature > 2)
  ) {
    return ElMessage.warning('温度取值应在 0 ~ 2 之间')
  }

  saving.value = true
  try {
    const payload: AgentPayload = {
      ...form,
      code: form.code.trim(),
      name: form.name.trim(),
      description: (form.description ?? '').trim() || undefined,
      promptName: (form.promptName ?? '').trim() || undefined,
      promptOverride: (form.promptOverride ?? '').trim() || undefined,
      toolsConfig:
        (form.toolsConfig ?? '')
          .split(',')
          .map((s) => s.trim())
          .filter(Boolean)
          .join(',') || undefined,
      strategy: form.strategy || undefined,
      model: (form.model ?? '').trim() || undefined,
      maxIterations: form.maxIterations ?? null,
    }
    if (editingId.value) {
      await updateAgent(editingId.value, payload)
      ElMessage.success('已保存')
    } else {
      await createAgent(payload)
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
const handleSetActive = async (item: AgentItem) => {
  try {
    await ElMessageBox.confirm(
      `将 Agent「${item.name}」（${item.code}）设为当前激活配置？\n切换后请到“运行态”点击“立即应用配置”并核验生效版本。`,
      '设为激活',
      { confirmButtonText: '激活', cancelButtonText: '取消', type: 'warning' },
    )
  } catch {
    return
  }
  try {
    await setAgentActive(item.id)
    ElMessage.success('已设为激活')
    await loadList()
  } catch {
    // 业务失败由 http 拦截器提示
  }
}

const handleToggle = async (item: AgentItem) => {
  const enable = item.status !== 1
  try {
    await ElMessageBox.confirm(
      enable ? `确认启用 Agent「${item.name}」？` : `确认停用 Agent「${item.name}」？`,
      enable ? '启用 Agent' : '停用 Agent',
      { confirmButtonText: enable ? '启用' : '停用', cancelButtonText: '取消', type: 'warning' },
    )
  } catch {
    return
  }
  try {
    await toggleAgent(item.id)
    ElMessage.success(enable ? '已启用' : '已停用')
    await loadList()
  } catch {
    // 业务失败由 http 拦截器提示
  }
}

const handleDelete = async (item: AgentItem) => {
  try {
    await ElMessageBox.confirm(
      `确认删除 Agent「${item.name}」？删除后不可恢复。`,
      '删除 Agent',
      { confirmButtonText: '删除', cancelButtonText: '取消', type: 'error' },
    )
  } catch {
    return
  }
  try {
    await deleteAgent(item.id)
    ElMessage.success('已删除')
    await loadList()
  } catch {
    // 业务失败由 http 拦截器提示
  }
}

// ---------- 辅助 ----------
const toolsLabel = (cfg: string | null) =>
  cfg ? cfg.split(',').map((s) => s.trim()).filter(Boolean) : []
const toolsText = (cfg: string | null) => toolsLabel(cfg).join(' / ') || '-'

onMounted(loadList)

// ---------- 从内置基线导入 ----------
const baselineVisible = ref(false)
const baselineItems = ref<Array<{ code: string; name: string; description: string; checked: boolean }>>([])
const baselineLoading = ref(false)
const importing = ref(false)

const openBaseline = async () => {
  baselineVisible.value = true
  baselineLoading.value = true
  try {
    const map = await getAgentBaseline()
    baselineItems.value = Object.entries<BaselineItem>(map ?? {}).map(([code, v]) => ({
      code,
      name: v.name ?? code,
      description: v.description ?? '',
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
  const codes = baselineItems.value.filter((i) => i.checked).map((i) => i.code)
  if (!codes.length) return ElMessage.warning('请先勾选要导入的 Agent')
  importing.value = true
  try {
    const n = await importAgentBaseline(codes)
    ElMessage.success(`已导入 ${n} 条内置 Agent（已存在的自动跳过）`)
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
        <span>Agent 管理</span>
        <h1>智能体行为元参数热改</h1>
      </div>
      <div class="head-actions">
        <el-button round @click="openBaseline">
          <el-icon style="margin-right: 4px"><Download /></el-icon>从内置基线导入
        </el-button>
        <el-button type="primary" round @click="openCreate">
          <el-icon style="margin-right: 4px"><Plus /></el-icon>新增 Agent
        </el-button>
      </div>
    </section>

    <!-- 热生效说明 -->
    <section class="surface-card hot-tip">
      <el-icon class="hot-icon"><Lightning /></el-icon>
      <div>
        <strong>热生效机制</strong>
        <p>
          编排逻辑仍在 AI 中台，本表只管理「行为参数」：引用的提示词（prompt_name /
          直接覆盖文本 prompt_override）、采样参数（温度 / 最大 tokens）、启用工具（rag / vision）。
          未配置的 Agent 使用全局默认，平滑迁移；激活后可立即应用并在运行态核验。
        </p>
      </div>
    </section>

    <!-- 筛选 -->
    <section class="surface-card filter-bar">
      <el-input
        v-model="codeFilter"
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
            <p>暂无已入库 Agent。当前 AI 仍按内置参数运行。</p>
            <p>点击右上角「从内置基线导入」，把内置 Agent 元参数物化进数据库后即可在线热改。</p>
          </div>
        </template>
        <el-table-column prop="name" label="Agent" width="160">
          <template #default="{ row }">
            <span class="name">{{ row.name }}</span>
            <el-tag v-if="row.isActive" type="success" size="small" effect="dark" class="active-tag">
              激活
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="code" label="逻辑键" width="130">
          <template #default="{ row }"><code class="mono">{{ row.code }}</code></template>
        </el-table-column>
        <el-table-column label="提示词引用" min-width="150" show-overflow-tooltip>
          <template #default="{ row }">
            <code class="mono">{{ row.promptName || row.code }}</code>
            <el-tag v-if="row.promptOverride" size="small" type="warning" effect="plain" class="ovr-tag">
              覆盖
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="采样参数" width="150">
          <template #default="{ row }">
            <span class="sub">{{ row.temperature != null ? `温度 ${row.temperature}` : '温度 默认' }}</span>
            <span class="sub">{{ row.maxTokens != null ? ` / ${row.maxTokens} tok` : '`' }}</span>
          </template>
        </el-table-column>
        <el-table-column label="启用工具" width="140">
          <template #default="{ row }">
            <span class="sub">{{ toolsText(row.toolsConfig) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="策略 / 模型" min-width="170">
          <template #default="{ row }">
            <span class="sub">{{ row.strategy || 'CODE' }}</span>
            <span class="sub">{{ row.model ? ` / ${row.model}` : '' }}</span>
            <span v-if="row.maxIterations" class="sub"> / ≤{{ row.maxIterations }}轮</span>
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
      :title="editingId ? '编辑 Agent' : '新增 Agent'"
      width="680px"
      :close-on-click-modal="false"
    >
      <el-form label-width="100px" label-position="top">
        <div class="form-grid">
          <el-form-item label="Agent 逻辑键" required>
            <el-input v-model="form.code" placeholder="如：sp / mentor / evaluator / reviewer" />
          </el-form-item>
          <el-form-item label="显示名称" required>
            <el-input v-model="form.name" placeholder="如：标准病人智能体" />
          </el-form-item>
        </div>

        <div class="form-grid">
          <el-form-item label="温度覆盖（0-2）">
            <el-input-number
              v-model="form.temperature"
              :min="0"
              :max="2"
              :step="0.1"
              controls-position="right"
              style="width: 100%"
            />
          </el-form-item>
          <el-form-item label="最大 Tokens 覆盖">
            <el-input-number
              v-model="form.maxTokens"
              :min="1"
              :max="32768"
              controls-position="right"
              style="width: 100%"
            />
          </el-form-item>
        </div>

        <div class="form-grid">
          <el-form-item label="引用提示词逻辑键">
            <el-input v-model="form.promptName" placeholder="留空=与 Agent 逻辑键同名" />
          </el-form-item>
          <el-form-item label="启用工具（逗号分隔）">
            <el-input v-model="form.toolsConfig" placeholder="如 rag / vision，英文逗号分隔" />
          </el-form-item>
        </div>

        <div class="form-grid">
          <el-form-item label="执行策略">
            <el-select v-model="form.strategy" style="width: 100%">
              <el-option label="CODE · 一次性直出" value="CODE" />
              <el-option label="TOOL · 带工具调用（需 toolsConfig 含 rag）" value="TOOL" />
              <el-option label="LOOP · 自主循环（预留）" value="LOOP" />
            </el-select>
          </el-form-item>
          <el-form-item label="指定模型（留空用全局）">
            <el-input v-model="form.model" placeholder="如 qwen-plus / deepseek-chat（可选）" />
          </el-form-item>
        </div>

        <div class="form-grid">
          <el-form-item label="最大迭代轮数（TOOL/LOOP）">
            <el-input-number
              v-model="form.maxIterations"
              :min="1"
              :max="10"
              controls-position="right"
              style="width: 100%"
            />
          </el-form-item>
          <el-form-item label="职责说明">
            <el-input v-model="form.description" placeholder="此 Agent 的职责（可选）" />
          </el-form-item>
        </div>

        <el-form-item label="System Prompt 直接覆盖">
          <el-input
            v-model="form.promptOverride"
            type="textarea"
            :rows="4"
            placeholder="非空时优先于引用的提示词生效（直接作为该 Agent 的 system prompt）。留空则走「引用提示词 → 内置模板」。"
          />
        </el-form-item>

        <div class="form-grid">
          <el-form-item label="状态">
            <el-radio-group v-model="form.status">
              <el-radio :value="1">启用</el-radio>
              <el-radio :value="0">停用</el-radio>
            </el-radio-group>
          </el-form-item>
        </div>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="handleSave">保存</el-button>
      </template>
    </el-dialog>

    <!-- 内置 Agent 基线导入抽屉 -->
    <el-drawer v-model="baselineVisible" title="从内置基线导入 Agent" size="480px">
      <p class="base-desc">
        左侧为 AI 中台内置 Agent 元参数（温度/字数/工具声明）。导入后写入数据库
        <code>ai_agent</code>，即可在线编辑并「设激活」，随后在运行态立即应用并核验生成型 Agent。
        <strong>已存在的逻辑键会自动跳过</strong>。
      </p>
      <div class="base-op">
        <span>共 {{ baselineItems.length }} 项</span>
        <div>
          <el-button link size="small" @click="toggleAll(true)">全选</el-button>
          <el-button link size="small" @click="toggleAll(false)">清空</el-button>
        </div>
      </div>
      <div v-loading="baselineLoading" class="base-list">
        <el-checkbox-group :model-value="baselineItems.filter((i) => i.checked).map((i) => i.code)">
          <div v-for="item in baselineItems" :key="item.code" class="base-item">
            <el-checkbox :value="item.code" @change="(v: boolean | string | number) => (item.checked = !!v)" />
            <div class="base-item-body">
              <div class="base-item-head">
                <code class="mono">{{ item.code }}</code>
                <span>{{ item.name }}</span>
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

.name {
  color: var(--zy-ink);
  font-weight: 800;
}

.active-tag {
  margin-left: 8px;
}

.mono {
  padding: 2px 6px;
  border-radius: 6px;
  background: var(--zy-surface-soft);
  color: var(--zy-ink);
  font-size: 12px;
}

.ovr-tag {
  margin-left: 6px;
}

.sub {
  display: block;
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
