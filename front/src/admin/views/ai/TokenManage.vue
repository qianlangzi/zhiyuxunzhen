<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import * as echarts from 'echarts/core'
import { BarChart, LineChart, PieChart } from 'echarts/charts'
import {
  GridComponent,
  LegendComponent,
  TooltipComponent,
} from 'echarts/components'
import { CanvasRenderer } from 'echarts/renderers'
import {
  deleteTokenQuota,
  getTokenOverview,
  getTokenRank,
  getTokenTrend,
  listTokenQuota,
  saveTokenQuota,
  type TokenOverview,
  type TokenQuotaItem,
  type TokenQuotaPayload,
  type TokenRankItem,
  type TokenTrendPoint,
} from '../../api/token'

echarts.use([
  LineChart,
  BarChart,
  PieChart,
  GridComponent,
  TooltipComponent,
  LegendComponent,
  CanvasRenderer,
])

// ---------- 数据 ----------
const overview = ref<TokenOverview | null>(null)
const trend = ref<TokenTrendPoint[]>([])
const modelRank = ref<TokenRankItem[]>([])
const sceneRank = ref<TokenRankItem[]>([])
const quotas = ref<TokenQuotaItem[]>([])
const loading = ref(false)

async function loadAll(): Promise<void> {
  loading.value = true
  try {
    const [ov, tr, mr, sr, q] = await Promise.all([
      getTokenOverview(),
      getTokenTrend(30),
      getTokenRank('model', 30),
      getTokenRank('scene', 30),
      listTokenQuota(),
    ])
    overview.value = ov
    trend.value = tr
    modelRank.value = mr
    sceneRank.value = sr
    quotas.value = q
    renderCharts()
  } catch {
    // 错误由 http 拦截器统一提示
  } finally {
    loading.value = false
  }
}

// ---------- 展示 ----------
function fmtTokens(v: number | null | undefined): string {
  const n = v ?? 0
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(2)}M`
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`
  return String(n)
}

const overviewCards = computed(() => {
  const ov = overview.value
  if (!ov) return []
  return [
    { label: '今日消耗', value: fmtTokens(ov.todayTokens), sub: `${ov.todayCalls} 次调用`, icon: 'Coin', tone: 'brand' },
    { label: '本月消耗', value: fmtTokens(ov.monthTokens), sub: `${ov.monthCalls} 次调用`, icon: 'TrendCharts', tone: 'info' },
    { label: '累计消耗', value: fmtTokens(ov.totalTokens), sub: '上线以来', icon: 'DataLine', tone: 'success' },
    { label: '平均耗时', value: `${ov.avgLatencyMs}ms`, sub: `本月失败 ${ov.monthFailedCalls} 次`, icon: 'Timer', tone: 'warning' },
  ]
})

const quotaPercent = computed(() => overview.value?.monthUsedPercent ?? null)

const quotaBarColor = computed(() => {
  const p = quotaPercent.value ?? 0
  if (p >= 100) return 'var(--zy-danger)'
  if (p >= 80) return 'var(--zy-warning)'
  return 'var(--zy-brand)'
})

const alerts = computed(() => overview.value?.alerts ?? [])

// ---------- 图表 ----------
const trendChartEl = ref<HTMLElement | null>(null)
const rankChartEl = ref<HTMLElement | null>(null)
let trendChart: ReturnType<typeof echarts.init> | null = null
let rankChart: ReturnType<typeof echarts.init> | null = null
let resizeHandler: (() => void) | null = null

function chartTextColors() {
  const dark = document.documentElement.classList.contains('dark')
  return { ink: dark ? '#e6eef0' : '#102023', muted: dark ? '#9fb3b8' : '#5a686b' }
}

function renderCharts(): void {
  renderTrend()
  renderRank()
  if (!resizeHandler) {
    resizeHandler = () => {
      trendChart?.resize()
      rankChart?.resize()
    }
    window.addEventListener('resize', resizeHandler)
  }
}

function renderTrend(): void {
  if (!trendChartEl.value) return
  if (!trendChart) trendChart = echarts.init(trendChartEl.value)
  const { ink, muted } = chartTextColors()
  trendChart.setOption({
    tooltip: {
      trigger: 'axis',
      valueFormatter: (v: unknown) => fmtTokens(Number(v)),
    },
    legend: { data: ['总消耗', '输入', '输出', '调用次数'], textStyle: { color: muted }, top: 0 },
    grid: { left: 8, right: 8, top: 34, bottom: 0, containLabel: true },
    xAxis: {
      type: 'category',
      data: trend.value.map((p) => p.label.slice(5)),
      axisLine: { lineStyle: { color: muted } },
      axisLabel: { color: muted },
    },
    yAxis: [
      { type: 'value', axisLabel: { color: muted, formatter: (v: number) => fmtTokens(v) }, splitLine: { lineStyle: { color: 'rgba(128,148,152,0.15)' } } },
      { type: 'value', name: '调用', axisLabel: { color: muted }, splitLine: { show: false } },
    ],
    series: [
      {
        name: '总消耗',
        type: 'line',
        smooth: true,
        symbol: 'none',
        data: trend.value.map((p) => p.totalTokens),
        lineStyle: { width: 2.5, color: '#0f4c5c' },
        areaStyle: { color: 'rgba(15,76,92,0.10)' },
      },
      {
        name: '输入',
        type: 'line',
        smooth: true,
        symbol: 'none',
        data: trend.value.map((p) => p.promptTokens),
        lineStyle: { width: 1.5, color: '#6b98a5', type: 'dashed' },
      },
      {
        name: '输出',
        type: 'line',
        smooth: true,
        symbol: 'none',
        data: trend.value.map((p) => p.completionTokens),
        lineStyle: { width: 1.5, color: '#247a5a', type: 'dashed' },
      },
      {
        name: '调用次数',
        type: 'bar',
        yAxisIndex: 1,
        barMaxWidth: 14,
        itemStyle: { color: 'rgba(167,99,27,0.35)', borderRadius: [4, 4, 0, 0] },
        data: trend.value.map((p) => p.calls),
      },
    ],
  })
}

function renderRank(): void {
  if (!rankChartEl.value) return
  if (!rankChart) rankChart = echarts.init(rankChartEl.value)
  const { ink, muted } = chartTextColors()
  const data = modelRank.value.slice(0, 6)
  rankChart.setOption({
    tooltip: {
      trigger: 'item',
      valueFormatter: (v: unknown) => fmtTokens(Number(v)),
    },
    legend: { bottom: 0, textStyle: { color: muted } },
    series: [
      {
        type: 'pie',
        radius: ['46%', '72%'],
        center: ['50%', '44%'],
        label: { color: ink, formatter: '{b}\n{d}%' },
        labelLine: { lineStyle: { color: muted } },
        data: data.map((r) => ({ name: r.name || '(未标注)', value: r.totalTokens })),
      },
    ],
  })
}

// ---------- 配额维护 ----------
const quotaDialog = ref<{ visible: boolean; saving: boolean; form: TokenQuotaPayload }>({
  visible: false,
  saving: false,
  form: { model: '', monthlyQuota: 0, warnPercent: 80, status: 1, remark: '' },
})

function openQuotaDialog(row?: TokenQuotaItem): void {
  quotaDialog.value.form = row
    ? { id: row.id, model: row.model, monthlyQuota: row.monthlyQuota, warnPercent: row.warnPercent, status: row.status, remark: row.remark ?? '' }
    : { model: '', monthlyQuota: 0, warnPercent: 80, status: 1, remark: '' }
  quotaDialog.value.visible = true
}

async function submitQuota(): Promise<void> {
  const f = quotaDialog.value.form
  if (!f.model.trim()) {
    ElMessage.warning('请填写模型标识')
    return
  }
  quotaDialog.value.saving = true
  try {
    await saveTokenQuota({ ...f, model: f.model.trim() })
    ElMessage.success('配额已保存')
    quotaDialog.value.visible = false
    quotas.value = await listTokenQuota()
    overview.value = await getTokenOverview()
  } catch {
    // 错误由 http 拦截器统一提示
  } finally {
    quotaDialog.value.saving = false
  }
}

async function onQuotaDelete(row: TokenQuotaItem): Promise<void> {
  try {
    await ElMessageBox.confirm(`删除「${row.model}」的配额配置？`, '删除确认', {
      type: 'warning',
      confirmButtonText: '删除',
      cancelButtonText: '取消',
    })
    await deleteTokenQuota(row.id)
    ElMessage.success('已删除')
    quotas.value = await listTokenQuota()
  } catch {
    // 用户取消或错误由拦截器提示
  }
}

function quotaTagType(row: TokenQuotaItem): 'danger' | 'warning' | 'success' | 'info' {
  if (row.exceeded) return 'danger'
  if (row.warning) return 'warning'
  if (row.monthlyQuota > 0) return 'success'
  return 'info'
}

onMounted(loadAll)

onBeforeUnmount(() => {
  trendChart?.dispose()
  rankChart?.dispose()
  if (resizeHandler) window.removeEventListener('resize', resizeHandler)
})
</script>

<template>
  <div class="admin-page">
    <!-- 页头 -->
    <section class="admin-page-head">
      <div>
        <span>AI 配置中心 · Token 管理</span>
        <h1>大模型用量观测与配额治理</h1>
      </div>
      <el-button :loading="loading" @click="loadAll">
        <el-icon><Refresh /></el-icon>&nbsp;刷新数据
      </el-button>
    </section>

    <!-- 配额告警横幅 -->
    <el-alert
      v-for="a in alerts"
      :key="a.model"
      :type="a.level === 'exceeded' ? 'error' : 'warning'"
      :closable="false"
      class="quota-alert"
    >
      <template #title>
        {{ a.level === 'exceeded' ? '已超额' : '接近配额' }}：
        模型 {{ a.model }} 本月已消耗 {{ fmtTokens(a.usedTokens) }} tokens
        （配额 {{ fmtTokens(a.monthlyQuota) }}，{{ a.usedPercent }}%）
      </template>
    </el-alert>

    <!-- 指标卡 -->
    <div class="metric-grid">
      <div v-for="card in overviewCards" :key="card.label" class="adm-card metric-card">
        <div class="metric-icon" :class="`tone-${card.tone}`">
          <el-icon :size="18"><component :is="card.icon" /></el-icon>
        </div>
        <div class="metric-text">
          <span class="metric-label">{{ card.label }}</span>
          <strong class="metric-value">{{ card.value }}</strong>
          <span class="metric-sub">{{ card.sub }}</span>
        </div>
      </div>
    </div>

    <!-- 本月配额进度 -->
    <div v-if="quotaPercent !== null" class="adm-card quota-bar-card">
      <div class="quota-bar-head">
        <span>本月配额总进度</span>
        <strong :style="{ color: quotaBarColor }">{{ quotaPercent }}%</strong>
      </div>
      <el-progress
        :percentage="Math.min(quotaPercent, 100)"
        :color="quotaBarColor"
        :stroke-width="10"
        :show-text="false"
      />
      <p class="quota-bar-sub">
        已配置配额合计 {{ fmtTokens(overview?.monthQuota ?? 0) }} tokens ·
        覆盖范围内的模型已消耗约 {{ quotaPercent }}%
      </p>
    </div>

    <!-- 图表区 -->
    <div class="chart-grid">
      <div class="adm-card">
        <div class="adm-card-head">
          <h3>近 30 天用量趋势</h3>
        </div>
        <div class="adm-card-body chart-body">
          <div ref="trendChartEl" class="chart-tall" />
        </div>
      </div>

      <div class="adm-card">
        <div class="adm-card-head">
          <h3>模型消耗占比（30 天）</h3>
        </div>
        <div class="adm-card-body chart-body">
          <div ref="rankChartEl" class="chart-tall" />
        </div>
      </div>
    </div>

    <!-- 排行表 -->
    <div class="rank-grid">
      <div class="adm-card">
        <div class="adm-card-head"><h3>按模型排行</h3></div>
        <div class="adm-card-body">
          <el-table :data="modelRank" size="small" :default-sort="{ prop: 'totalTokens', order: 'descending' }">
            <el-table-column prop="name" label="模型" min-width="150" show-overflow-tooltip />
            <el-table-column prop="totalTokens" label="消耗" width="90" sortable>
              <template #default="{ row }">{{ fmtTokens(row.totalTokens) }}</template>
            </el-table-column>
            <el-table-column prop="calls" label="调用" width="80" sortable />
            <el-table-column prop="percent" label="占比" width="80">
              <template #default="{ row }">{{ row.percent }}%</template>
            </el-table-column>
            <el-table-column prop="avgLatencyMs" label="均耗时" width="80">
              <template #default="{ row }">{{ row.avgLatencyMs }}ms</template>
            </el-table-column>
          </el-table>
        </div>
      </div>

      <div class="adm-card">
        <div class="adm-card-head"><h3>按场景排行</h3></div>
        <div class="adm-card-body">
          <el-table :data="sceneRank" size="small">
            <el-table-column prop="name" label="场景" min-width="120" show-overflow-tooltip />
            <el-table-column prop="totalTokens" label="消耗" width="90">
              <template #default="{ row }">{{ fmtTokens(row.totalTokens) }}</template>
            </el-table-column>
            <el-table-column prop="calls" label="调用" width="80" />
            <el-table-column prop="percent" label="占比" width="80">
              <template #default="{ row }">{{ row.percent }}%</template>
            </el-table-column>
          </el-table>
        </div>
      </div>
    </div>

    <!-- 配额配置 -->
    <div class="adm-card">
      <div class="adm-card-head">
        <h3>模型月度配额</h3>
        <el-button type="primary" plain size="small" @click="openQuotaDialog()">
          <el-icon><Plus /></el-icon>&nbsp;新增配额
        </el-button>
      </div>
      <div class="adm-card-body">
        <el-table :data="quotas">
          <el-table-column prop="model" label="模型" min-width="160" show-overflow-tooltip />
          <el-table-column label="月配额" width="110">
            <template #default="{ row }">
              {{ row.monthlyQuota > 0 ? fmtTokens(row.monthlyQuota) : '不限' }}
            </template>
          </el-table-column>
          <el-table-column label="本月已用" width="110">
            <template #default="{ row }">{{ fmtTokens(row.usedTokens) }}</template>
          </el-table-column>
          <el-table-column label="使用率" min-width="160">
            <template #default="{ row }">
              <el-progress
                v-if="row.usedPercent !== null"
                :percentage="Math.min(row.usedPercent, 100)"
                :color="row.exceeded ? 'var(--zy-danger)' : row.warning ? 'var(--zy-warning)' : 'var(--zy-brand)'"
                :stroke-width="8"
              />
              <span v-else class="muted-cell">—</span>
            </template>
          </el-table-column>
          <el-table-column label="状态" width="90">
            <template #default="{ row }">
              <el-tag size="small" :type="quotaTagType(row)" effect="plain">
                {{ row.exceeded ? '已超额' : row.warning ? '告警' : row.monthlyQuota > 0 ? '正常' : '不限' }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="warnPercent" label="阈值" width="70">
            <template #default="{ row }">{{ row.warnPercent }}%</template>
          </el-table-column>
          <el-table-column label="操作" width="130" fixed="right">
            <template #default="{ row }">
              <el-button link type="primary" size="small" @click="openQuotaDialog(row)">编辑</el-button>
              <el-button link type="danger" size="small" @click="onQuotaDelete(row)">删除</el-button>
            </template>
          </el-table-column>
          <template #empty>
            <el-empty description="尚未配置配额——添加后可在用量达到阈值时收到告警" :image-size="80" />
          </template>
        </el-table>
      </div>
    </div>

    <!-- 配额编辑对话框 -->
    <el-dialog v-model="quotaDialog.visible" title="模型配额" width="460">
      <el-form label-width="110px">
        <el-form-item label="模型标识">
          <el-input v-model="quotaDialog.form.model" placeholder="如 deepseek-chat" :disabled="!!quotaDialog.form.id" />
        </el-form-item>
        <el-form-item label="月度配额">
          <el-input-number v-model="quotaDialog.form.monthlyQuota" :min="0" :step="100000" :controls="false" style="width: 100%" />
          <span class="form-tip">0 表示不限制</span>
        </el-form-item>
        <el-form-item label="告警阈值 %">
          <el-input-number v-model="quotaDialog.form.warnPercent" :min="1" :max="100" style="width: 100%" />
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="quotaDialog.form.remark" placeholder="选填" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="quotaDialog.visible = false">取消</el-button>
        <el-button type="primary" :loading="quotaDialog.saving" @click="submitQuota">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.quota-alert {
  border-radius: 10px;
}

/* 指标卡 */
.metric-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 12px;
}

@media (max-width: 1100px) {
  .metric-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

.metric-card {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 16px;
}

.metric-icon {
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

.metric-text {
  min-width: 0;
}

.metric-label {
  display: block;
  color: var(--zy-muted);
  font-size: 12.5px;
}

.metric-value {
  display: block;
  margin-top: 2px;
  color: var(--zy-ink);
  font-size: 22px;
  line-height: 1.1;
  font-variant-numeric: tabular-nums;
}

.metric-sub {
  display: block;
  margin-top: 2px;
  color: var(--zy-soft);
  font-size: 12px;
}

/* 配额总进度 */
.quota-bar-card {
  padding: 14px 18px;
}

.quota-bar-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 10px;
  color: var(--zy-ink);
  font-size: 14px;
  font-weight: 600;
}

.quota-bar-sub {
  margin: 8px 0 0;
  color: var(--zy-muted);
  font-size: 12.5px;
}

/* 图表 */
.chart-grid {
  display: grid;
  grid-template-columns: 3fr 2fr;
  gap: 12px;
}

@media (max-width: 1100px) {
  .chart-grid {
    grid-template-columns: 1fr;
  }
}

.chart-body {
  padding: 12px 16px 16px;
}

.chart-tall {
  width: 100%;
  height: 320px;
}

/* 排行 */
.rank-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

@media (max-width: 1100px) {
  .rank-grid {
    grid-template-columns: 1fr;
  }
}

.muted-cell {
  color: var(--zy-muted);
}

.form-tip {
  display: block;
  margin-top: 4px;
  color: var(--zy-soft);
  font-size: 12px;
}
</style>
