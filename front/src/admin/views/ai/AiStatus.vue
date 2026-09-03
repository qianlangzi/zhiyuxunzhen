<script setup lang="ts">
import { onMounted, onUnmounted, ref, computed } from 'vue'
import { getConfigStatus, refreshAiConfig, getModelEvents, importPromptBaseline, importAgentBaseline, setPromptActive, setAgentActive, listPrompts, listAgents, type AiStatusData, type ModelEventItem } from '../../api/aiConfig'
import { ElMessage, ElMessageBox } from 'element-plus'

const loading = ref(false)
const data = ref<AiStatusData | null>(null)
const loadError = ref('')
const refreshing = ref(false)

// 最近模型事件（独立于运行态快照加载，避免事件接口异常影响整体状态）
const events = ref<ModelEventItem[]>([])
const eventsLoading = ref(false)
const eventsError = ref('')

// 模型事件时间范围筛选（前端过滤，接口保持轻量）
const eventRange = ref<[Date, Date] | null>(null)

const load = async () => {
  loading.value = true
  loadError.value = ''
  await Promise.all([loadStatus(), loadEvents()])
  loading.value = false
}

const loadStatus = async (silent = false) => {
  if (!silent) loading.value = true
  try {
    const res = await getConfigStatus()
    data.value = res
    if (res?.offline) loadError.value = ''
  } catch (e) {
    if (!silent) {
      data.value = null
      loadError.value = '运行态读取失败，请确认后端服务正常。'
    }
  } finally {
    if (!silent) loading.value = false
  }
}

const loadEvents = async () => {
  eventsLoading.value = true
  eventsError.value = ''
  try {
    events.value = await getModelEvents(20)
  } catch (e) {
    events.value = []
    eventsError.value = '最近模型事件读取失败，请确认后端服务正常。'
  } finally {
    eventsLoading.value = false
  }
}

// 30s 静默轮询：与 AI 中台配置同步周期对齐，页签不可见时暂停
let pollTimer: number | null = null
const startPolling = () => {
  if (pollTimer !== null) return
  pollTimer = window.setInterval(() => {
    if (document.hidden) return
    loadStatus(true)
  }, 30_000)
}
const stopPolling = () => {
  if (pollTimer !== null) {
    window.clearInterval(pollTimer)
    pollTimer = null
  }
}
onUnmounted(stopPolling)

const refreshNow = async () => {
  refreshing.value = true
  try {
    const result = await refreshAiConfig()
    await load()
    const version = result?.modelRegistry?.version
    if (result?.ok === false) {
      ElMessage.warning(result.modelRegistry?.last_error || '配置刷新失败，仍在使用上一份有效快照')
    } else {
      ElMessage.success(version ? `配置已刷新，模型快照 ${version}` : '配置刷新请求已完成')
    }
  } catch {
    ElMessage.error('配置刷新失败，请查看运行态中的最近错误')
  } finally {
    refreshing.value = false
  }
}

const isOffline = computed(() => !!data.value?.offline)
const app = computed(() => data.value?.app)
const refresh = computed(() => data.value?.refresh)
const effective = computed(() => data.value?.effective)
const models = computed(() => data.value?.models)
const refreshIntervalSeconds = computed(() => data.value?.refreshIntervalSeconds ?? 30)

const fmtTime = (ts?: string | null) => (ts ? new Date(ts).toLocaleString('zh-CN') : '—')

const sourceTag = (s?: string) => (s === 'database' ? 'success' : 'info')
const sourceLabel = (s?: string) => (s === 'database' ? '数据库生效' : '内置回退')

// 最近模型事件：类型 → 管理端可读标签与着色（正常/降级/超时/模型错误/恢复）
const eventMeta = (row: ModelEventItem) => {
  if (row.recovered || row.eventType === 'recovered') {
    return { text: '已恢复', type: 'success' as const }
  }
  switch (row.eventType) {
    case 'degradation':
      return { text: '已降级', type: 'warning' as const }
    case 'timeout':
      return { text: '超时', type: 'warning' as const }
    case 'model_error':
    case 'error':
      return { text: '模型错误', type: 'danger' as const }
    case 'info':
    case 'normal':
      return { text: '正常', type: 'success' as const }
    default:
      return { text: '信息', type: 'info' as const }
  }
}

const eventDesc = (row: ModelEventItem) =>
  row.errorMessage || eventMeta(row).text

const capabilityLabel = (c?: string | null) => {
  const map: Record<string, string> = {
    LLM: '大模型(LLM)',
    VISION: '多模态(VISION)',
    EMBEDDING: '文本向量(EMBEDDING)',
    EMBEDDING_MULTI: '多模态向量',
    fallback: '规则降级',
  }
  return (c && map[c]) || c || '—'
}

const traceId = (row: ModelEventItem) => (row.traceId && row.traceId !== '-' ? row.traceId : null)

// 异常/超时/降级事件行高亮，便于一眼定位问题模型
const eventRowClass = ({ row }: { row: ModelEventItem }) => {
  if (row.recovered || row.eventType === 'recovered') return 'events-row-recovered'
  if (row.eventType === 'model_error' || row.eventType === 'error') return 'events-row-error'
  if (row.eventType === 'timeout' || row.eventType === 'degradation') return 'events-row-warn'
  return ''
}

const refreshItems = computed(() => {
  const r = refresh.value
  if (!r) return []
  const last = r.last_refresh ?? {}
  const errs = r.last_errors ?? {}
  return [
    { key: 'prompt', label: '提示词', count: r.prompt_count, ts: last.prompt, err: errs.prompt },
    { key: 'agent', label: 'Agent', count: r.agent_count, ts: last.agent, err: errs.agent },
    { key: 'runtime', label: 'RAG 参数', count: r.runtime_count, ts: last.runtime, err: errs.runtime },
  ]
})

// 基线初始化引导：提示词/Agent 为 0 条且非同步错误 → 库里还没导入基线，
// AI 一直跑内置回退，热更新闭环未建立 → 引导一键导入并激活。
const needsBaselineInit = computed(() => {
  const r = refresh.value
  if (!r || isOffline.value) return false
  const errs = r.last_errors ?? {}
  return (r.prompt_count === 0 && !errs.prompt) || (r.agent_count === 0 && !errs.agent)
})

const importing = ref(false)

/** 一键导入内置基线 → 全部激活 → 立即应用，一步建立热更新闭环 */
const initBaseline = async () => {
  try {
    await ElMessageBox.confirm(
      '将把 AI 中台内置的提示词与 Agent 元参数基线导入数据库并全部激活（内容与当前内置模板一致，AI 行为不变），此后可在管理端热改即时生效。是否继续？',
      '一键导入基线配置',
      { confirmButtonText: '导入并激活', cancelButtonText: '取消', type: 'info' },
    )
  } catch {
    return
  }
  importing.value = true
  try {
    const [pCount, aCount] = await Promise.all([importPromptBaseline(), importAgentBaseline()])
    // 导入后默认未激活 → 逐条激活（同 name/code 至多一个激活，接口幂等）
    const [{ list: prompts }, { list: agents }] = await Promise.all([
      listPrompts(1, 200),
      listAgents(1, 200),
    ])
    await Promise.all([
      ...prompts.filter((p) => !p.isActive).map((p) => setPromptActive(p.id)),
      ...agents.filter((a) => !a.isActive).map((a) => setAgentActive(a.id)),
    ])
    await refreshAiConfig()
    await load()
    ElMessage.success(`基线导入完成：提示词 ${pCount} 条、Agent ${aCount} 条已激活生效`)
  } catch {
    ElMessage.error('基线导入失败，请检查 AI 中台与后端服务是否正常')
  } finally {
    importing.value = false
  }
}

// 模型事件按时间范围过滤（前端过滤，最近 20 条内筛选）
const filteredEvents = computed(() => {
  if (!eventRange.value) return events.value
  const [start, end] = eventRange.value
  const s = new Date(start); s.setHours(0, 0, 0, 0)
  const e = new Date(end); e.setHours(23, 59, 59, 999)
  return events.value.filter((row) => {
    const t = row.createdAt ? new Date(row.createdAt).getTime() : 0
    return t >= s.getTime() && t <= e.getTime()
  })
})

const modelList = computed(() => Object.values(models.value ?? {}))

onMounted(() => {
  load()
  startPolling()
})
</script>

<template>
  <main class="admin-page">
    <section class="admin-page-head">
      <div>
        <span>运行态</span>
        <h1>AI 中台服务健康 · 配置同步 · 生效来源</h1>
      </div>
      <el-button round :loading="loading" @click="load">
        <el-icon style="margin-right: 4px"><Refresh /></el-icon>刷新
      </el-button>
      <el-button type="primary" round :loading="refreshing" @click="refreshNow">
        <el-icon style="margin-right: 4px"><Promotion /></el-icon>立即应用配置
      </el-button>
    </section>

    <!-- AI 中台离线 -->
    <section v-if="isOffline" class="surface-card offline-tip">
      <el-icon class="offline-icon"><Connection /></el-icon>
      <div>
        <strong>无法连接 AI 中台</strong>
        <p>
          后端无法通过内网调用 AI 中台的 <code>/internal/config/status</code>。
          请检查：① AI 中台容器是否已启动并健康；② 后端 <code>zhiyu.ai.base-url</code>
          是否指向 AI 中台可达地址；③ 两端 <code>zhiyu.ai.internal-token</code> 是否一致。
          排查结果为全链路「教师/学生端无法使用 AI 服务」的第一类常见原因。
        </p>
      </div>
    </section>
    <section v-else-if="loadError" class="surface-card offline-tip">
      <el-icon class="offline-icon"><Warning /></el-icon>
      <div><strong>运行态读取失败</strong><p>{{ loadError }}</p></div>
    </section>

    <template v-else-if="data">
      <!-- 基线初始化引导（0 条 ≠ 正常：热更新闭环未建立） -->
      <section v-if="needsBaselineInit" class="surface-card baseline-banner">
        <el-icon class="baseline-icon"><InfoFilled /></el-icon>
        <div class="baseline-text">
          <strong>提示词 / Agent 基线尚未导入数据库</strong>
          <p>当前 AI 全部按内置模板运行（功能正常但无法热改）。导入基线并激活后，即可在本管理端修改提示词 / Agent / RAG 参数并即时生效。</p>
        </div>
        <el-button type="primary" round :loading="importing" @click="initBaseline">
          <el-icon style="margin-right: 4px"><Download /></el-icon>一键导入并激活
        </el-button>
      </section>

      <!-- 服务健康 -->
      <section class="surface-card health-card">
        <div class="health-grid">
          <div class="health-cell">
            <span class="cell-label">应用</span>
            <strong class="cell-value">{{ app?.name }}</strong>
          </div>
          <div class="health-cell">
            <span class="cell-label">版本 / 环境</span>
            <strong class="cell-value">{{ app?.version }} · {{ app?.env }}</strong>
          </div>
          <div class="health-cell">
            <span class="cell-label">LLM 配置</span>
            <el-tag :type="app?.llm_configured ? 'success' : 'danger'" effect="dark">
              {{ app?.llm_configured ? '已配置' : '未配置（降级）' }}
            </el-tag>
          </div>
        </div>
      </section>

      <!-- 配置同步 -->
      <section class="surface-card">
        <h2 class="section-title">配置热同步（AI 中台每 {{ refreshIntervalSeconds }} 秒拉取一次）</h2>
        <div class="sync-grid">
          <div v-for="item in refreshItems" :key="item.key" class="sync-cell">
            <div class="sync-cell-head">
              <strong>{{ item.label }}</strong>
              <el-tag v-if="item.err" type="danger" size="small">失败</el-tag>
              <el-tag v-else-if="!item.count && item.key !== 'runtime'" type="warning" size="small" effect="plain">空（未导入）</el-tag>
              <el-tag v-else-if="!item.count" type="info" size="small" effect="plain">内置默认</el-tag>
              <el-tag v-else type="success" size="small" effect="plain">正常</el-tag>
            </div>
            <div class="sync-count">{{ item.count ? `已载入 ${item.count} 条` : '未载入任何配置' }}</div>
            <div class="sync-ts">最近同步：{{ fmtTime(item.ts) }}</div>
            <div v-if="item.err" class="sync-err">{{ item.err }}</div>
          </div>
        </div>
        <p v-if="refreshItems.every((i) => i.err)" class="section-hint">
          <el-icon><Warning /></el-icon>所有类别同步失败 → 通常是 AI 中台无法反向访问业务中台的
          <code>/api/internal/*</code>：请检查 AI 中台 <code>backend_callback_url</code> 与内网令牌。
        </p>
      </section>

      <section class="surface-card" v-if="data.modelRegistry">
        <h2 class="section-title">模型注册表运行态</h2>
        <div class="sync-grid">
          <div class="sync-cell"><strong>快照版本</strong><div class="sync-ts mono">{{ data.modelRegistry.version || '尚未成功刷新' }}</div></div>
          <div class="sync-cell"><strong>最近刷新</strong><div class="sync-ts">{{ fmtTime(data.modelRegistry.last_refresh_at) }}</div></div>
          <div class="sync-cell"><strong>活跃能力</strong><div class="sync-count">{{ data.modelRegistry.count }} 项：{{ data.modelRegistry.capabilities.join('、') || '无' }}</div></div>
        </div>
        <p v-if="data.modelRegistry.last_error" class="section-hint"><el-icon><Warning /></el-icon>最近刷新失败：{{ data.modelRegistry.last_error }}</p>
      </section>

      <!-- 生效来源 -->
      <section class="surface-card">
        <h2 class="section-title">各逻辑键生效来源（在当前配置下，AI 实际用的是哪一份）</h2>
        <p v-if="needsBaselineInit" class="section-hint section-hint--warn">
          <el-icon><Warning /></el-icon>以下全部为「内置回退」：基线尚未导入，管理端的热改对 AI 不生效。可点击上方「一键导入并激活」建立热更新闭环。
        </p>
        <div class="src-group">
          <div class="src-group-title">
            <span>提示词</span>
            <el-tag size="small" type="info">未入库的键仍按内置模板运行</el-tag>
          </div>
          <div class="src-grid">
            <div v-for="(v, name) in effective?.promptSource" :key="name" class="src-item">
              <code class="mono">{{ name }}</code>
              <span class="src-title">{{ v.title }}</span>
              <el-tag :type="sourceTag(v.source)" size="small" effect="plain">{{ sourceLabel(v.source) }}</el-tag>
            </div>
          </div>
        </div>

        <div class="src-group">
          <div class="src-group-title"><span>Agent 元参数</span></div>
          <div class="src-grid">
            <div v-for="(v, code) in effective?.agentSource" :key="code" class="src-item">
              <code class="mono">{{ code }}</code>
              <span class="src-title">{{ v.name }}</span>
              <el-tag :type="sourceTag(v.source)" size="small" effect="plain">{{ sourceLabel(v.source) }}</el-tag>
            </div>
          </div>
        </div>
      </section>

      <!-- RAG 生效值 -->
      <section class="surface-card" v-if="effective?.runtime">
        <h2 class="section-title">RAG 运行参数（当前生效值 vs 内置基线）</h2>
        <el-table :data="Object.entries(effective.runtime).map(([k, v]) => ({ key: k, ...v }))" stripe size="small">
          <el-table-column label="参数键" width="220">
            <template #default="{ row }"><code class="mono">{{ row.key }}</code></template>
          </el-table-column>
          <el-table-column label="当前生效值" width="140">
            <template #default="{ row }">
              <el-tag :type="row.source === 'database' ? 'success' : 'info'" effect="plain">
                {{ row.value }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column label="内置基线" prop="baseline" width="140" />
          <el-table-column label="来源">
            <template #default="{ row }">{{ row.source === 'database' ? '数据库覆盖' : '内置默认' }}</template>
          </el-table-column>
        </el-table>
      </section>

      <!-- 模型脱敏视图 -->
      <section class="surface-card" v-if="modelList.length">
        <h2 class="section-title">模型连接（脱敏视图 · 已隐藏密钥）</h2>
        <el-table :data="modelList" stripe size="small">
          <el-table-column prop="capability" label="能力" width="120" />
          <el-table-column prop="model" label="模型" min-width="160" />
          <el-table-column prop="host" label="服务地址(Host)" min-width="200" />
          <el-table-column label="状态" width="110">
            <template #default="{ row }">
              <el-tag :type="row.configured ? 'success' : 'danger'" effect="plain">
                {{ row.configured ? '已配置' : '未配置' }}
              </el-tag>
            </template>
          </el-table-column>
        </el-table>
      </section>

      <section class="surface-card" v-else-if="!isOffline">
        <h2 class="section-title">模型连接</h2>
        <p class="section-hint">模型注册表尚未拉取到活跃模型配置，请先到「模型管理」配置并激活对应能力的模型。</p>
      </section>

      <!-- 最近模型事件 -->
      <section class="surface-card events-card">
        <div class="events-head">
          <div>
            <h2 class="section-title">最近模型事件（最近 20 条 · 已脱敏）</h2>
            <p class="events-sub">AI 中台上报的降级 / 超时 / 模型错误 / 恢复事件，帮助判断当前哪个模型有问题、哪个 AI 能力受影响。</p>
          </div>
          <div class="events-actions">
            <el-date-picker
              v-model="eventRange"
              type="daterange"
              size="small"
              range-separator="至"
              start-placeholder="开始日期"
              end-placeholder="结束日期"
              :clearable="true"
              style="width: 240px"
            />
            <el-button round size="small" :loading="eventsLoading" @click="loadEvents">
              <el-icon style="margin-right: 4px"><Refresh /></el-icon>刷新事件
            </el-button>
          </div>
        </div>

        <div v-if="eventsError" class="events-empty">
          <el-icon class="events-empty-icon"><Warning /></el-icon>
          <p>{{ eventsError }}</p>
        </div>

        <div v-else-if="eventsLoading" class="events-empty" v-loading>
          <p class="events-empty-tip">正在加载最近模型事件…</p>
        </div>

        <div v-else-if="!events.length" class="events-empty">
          <el-icon class="events-empty-icon"><InfoFilled /></el-icon>
          <p class="events-empty-tip">暂无模型事件。</p>
          <p class="events-empty-sub">当 AI 中台出现模型降级、请求超时或模型错误时会记录到此处；正常时保持为空。</p>
        </div>

        <div v-else-if="!filteredEvents.length" class="events-empty">
          <el-icon class="events-empty-icon"><InfoFilled /></el-icon>
          <p class="events-empty-tip">所选时间范围内没有模型事件。</p>
          <p class="events-empty-sub">清空日期筛选可查看全部最近事件。</p>
        </div>

        <el-table v-else :data="filteredEvents" stripe size="small" :row-class-name="eventRowClass">
          <el-table-column label="时间" width="168">
            <template #default="{ row }"><span class="events-time">{{ fmtTime(row.createdAt) }}</span></template>
          </el-table-column>
          <el-table-column label="事件类型" width="104">
            <template #default="{ row }">
              <el-tag :type="eventMeta(row).type" effect="dark" size="small">{{ eventMeta(row).text }}</el-tag>
            </template>
          </el-table-column>
          <el-table-column label="模型 / 能力" width="210">
            <template #default="{ row }">
              <div class="events-model">
                <code class="mono">{{ row.modelName || '—' }}</code>
                <span class="events-cap">{{ capabilityLabel(row.capability) }}</span>
              </div>
            </template>
          </el-table-column>
          <el-table-column label="说明" min-width="220">
            <template #default="{ row }">
              <span class="events-desc">{{ eventDesc(row) }}</span>
            </template>
          </el-table-column>
          <el-table-column label="链路 ID (traceId)" width="180">
            <template #default="{ row }">
              <code v-if="traceId(row)" class="mono events-trace">{{ traceId(row) }}</code>
              <span v-else class="events-muted">—</span>
            </template>
          </el-table-column>
          <el-table-column label="是否恢复" width="96">
            <template #default="{ row }">
              <el-tag v-if="eventMeta(row).type === 'success' && (row.recovered || row.eventType === 'recovered')" type="success" size="small" effect="plain">已恢复</el-tag>
              <el-tag v-else-if="row.recovered" type="success" size="small" effect="plain">已恢复</el-tag>
              <span v-else class="events-muted">—</span>
            </template>
          </el-table-column>
        </el-table>
      </section>
    </template>

    <section v-else class="surface-card" v-loading="loading">
      <div class="empty-tip">正在读取 AI 中台运行态…</div>
    </section>
  </main>
</template>

<style scoped>
.admin-page-head {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 16px;
}

.surface-card {
  margin-bottom: 14px;
}

.offline-tip {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 16px;
}

.offline-icon {
  flex: none;
  margin-top: 3px;
  color: #d03050;
  font-size: 20px;
}

.offline-tip strong {
  color: var(--zy-ink);
  font-size: 15px;
}

.offline-tip p {
  margin: 6px 0 0;
  color: var(--zy-muted);
  font-size: 13px;
  line-height: 1.7;
}

.offline-tip code {
  padding: 1px 4px;
  border-radius: 4px;
  background: var(--zy-surface-soft);
  color: var(--zy-ink);
}

.health-card {
  padding: 16px;
}

.health-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 14px;
}

.health-cell {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.cell-label {
  color: var(--zy-muted);
  font-size: 12px;
}

.cell-value {
  color: var(--zy-ink);
  font-size: 15px;
}

.sync-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 12px;
}

.sync-cell {
  padding: 14px;
  border: 1px solid var(--zy-line);
  border-radius: 14px;
}

.sync-cell-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.sync-cell-head strong {
  color: var(--zy-ink);
}

.sync-count {
  margin-top: 8px;
  color: var(--zy-ink);
  font-size: 20px;
  font-weight: 800;
}

.sync-ts {
  margin-top: 4px;
  color: var(--zy-muted);
  font-size: 12px;
}

.sync-err {
  margin-top: 6px;
  color: #d03050;
  font-size: 12px;
  word-break: break-all;
}

.section-title {
  margin: 0 0 12px;
  color: var(--zy-ink);
  font-size: 14px;
  font-weight: 800;
}

.section-hint {
  display: flex;
  align-items: center;
  gap: 6px;
  margin: 12px 0 0;
  color: #d03050;
  font-size: 13px;
}

.section-hint--warn {
  color: #e6a23c;
}

/* 基线初始化引导横幅 */
.baseline-banner {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 14px 16px;
  border: 1px solid rgba(230, 162, 60, 0.45);
  background: rgba(230, 162, 60, 0.07);
}

.baseline-icon {
  flex: none;
  color: #e6a23c;
  font-size: 22px;
}

.baseline-text {
  flex: 1;
  min-width: 0;
}

.baseline-text strong {
  color: var(--zy-ink);
  font-size: 14px;
}

.baseline-text p {
  margin: 4px 0 0;
  color: var(--zy-muted);
  font-size: 12px;
  line-height: 1.6;
}

.events-actions {
  display: flex;
  align-items: center;
  gap: 8px;
  flex: none;
}

.src-group {
  margin-top: 14px;
}

.src-group-title {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 10px;
  color: var(--zy-muted);
  font-size: 13px;
}

.src-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  gap: 10px;
}

.src-item {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 12px;
  border: 1px solid var(--zy-line);
  border-radius: 12px;
}

.mono {
  padding: 2px 6px;
  border-radius: 6px;
  background: var(--zy-surface-soft);
  color: var(--zy-ink);
  font-size: 12px;
}

.src-title {
  flex: 1;
  min-width: 0;
  overflow: hidden;
  color: var(--zy-ink);
  font-size: 13px;
  white-space: nowrap;
  text-overflow: ellipsis;
}

.empty-tip {
  padding: 32px;
  color: var(--zy-muted);
  text-align: center;
}

/* 最近模型事件 */
.events-card {
  padding: 16px;
}

.events-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 12px;
}

.events-sub {
  margin: 4px 0 0;
  color: var(--zy-muted);
  font-size: 12px;
  line-height: 1.6;
}

.events-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  padding: 32px;
  color: var(--zy-muted);
  text-align: center;
}

.events-empty-icon {
  font-size: 28px;
  color: var(--zy-muted);
}

.events-empty-tip {
  color: var(--zy-ink);
  font-size: 14px;
  font-weight: 600;
}

.events-empty-sub {
  color: var(--zy-muted);
  font-size: 12px;
}

.events-time {
  color: var(--zy-muted);
  font-size: 12px;
}

.events-model {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.events-cap {
  color: var(--zy-muted);
  font-size: 12px;
}

.events-desc {
  color: var(--zy-ink);
  font-size: 13px;
}

.events-trace {
  font-family: var(--zy-mono, ui-monospace, monospace);
  font-size: 12px;
}

.events-muted {
  color: var(--zy-muted);
  font-size: 12px;
}

:deep(.events-row-error td) {
  background: rgba(208, 48, 80, 0.06) !important;
}

:deep(.events-row-warn td) {
  background: rgba(230, 162, 60, 0.06) !important;
}

:deep(.events-row-recovered td) {
  background: rgba(67, 160, 71, 0.05) !important;
}
</style>
