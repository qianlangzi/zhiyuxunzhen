<script setup lang="ts">
import { ref, computed, onMounted, onBeforeUnmount, nextTick } from 'vue'
import { fmtDateTime } from '../utils/format'
import * as echarts from 'echarts/core'
import { LineChart } from 'echarts/charts'
import {
  GridComponent,
  TooltipComponent,
  LegendComponent,
} from 'echarts/components'
import { CanvasRenderer } from 'echarts/renderers'
import {
  getDashboard,
  getUserOverview,
  getOnlineTrend,
  getRegisterTrend,
  getActiveTrend,
} from '../api/dashboard'
import type { DashboardVO, UserOverviewVO, TrendPointVO } from '../types'
import {
  listCaseAudits,
  listTeacherAudits,
  type CaseAuditItem,
  type TeacherAuditItem,
} from '../api/teacherAudit'
import { listAuditLogs, type AuditLogItem } from '../api/auditLog'

echarts.use([LineChart, GridComponent, TooltipComponent, LegendComponent, CanvasRenderer])

// ---------- Dashboard 真实数据 ----------
const dashboardData = ref<DashboardVO | null>(null)
const loading = ref(false)

// ---------- 用户数据看板 ----------
const overview = ref<UserOverviewVO | null>(null)
const onlineTrend = ref<TrendPointVO[]>([])
const registerTrend = ref<TrendPointVO[]>([])
const activeTrend = ref<TrendPointVO[]>([])
const statsLoading = ref(false)

const onlineChartEl = ref<HTMLDivElement>()
const trendChartEl = ref<HTMLDivElement>()
let onlineChart: ReturnType<typeof echarts.init> | null = null
let trendChart: ReturnType<typeof echarts.init> | null = null

// 品牌配色（与全局 CSS 变量保持一致）
const COLOR_TOTAL = '#0f4c5c'
const COLOR_STUDENT = '#247a5a'
const COLOR_TEACHER = '#a7631b'

/** 用户数据看板指标卡 */
const userStats = computed(() => {
  if (!overview.value) return []
  const o = overview.value
  return [
    { label: '注册账号总数', value: o.totalUsers ?? 0, detail: `学生 ${o.studentCount ?? 0} · 教师 ${o.teacherCount ?? 0}` },
    { label: '今日新增注册', value: o.todayNewUsers ?? 0, detail: '今日新建的账号' },
    { label: '今日活跃用户', value: o.todayActiveUsers ?? 0, detail: '今日有登录行为' },
    { label: '当前在线', value: o.currentOnline ?? 0, detail: `学生 ${o.currentOnlineStudents ?? 0} · 教师 ${o.currentOnlineTeachers ?? 0}` },
    { label: '今日峰值在线', value: o.todayPeakOnline ?? 0, detail: `昨日峰值 ${o.yesterdayPeakOnline ?? 0}` },
    { label: '昨日活跃用户', value: o.yesterdayActiveUsers ?? 0, detail: '昨日有登录行为' },
  ]
})

// ---------- 待办审核（最近条目） ----------
const pendingCases = ref<CaseAuditItem[]>([])
const pendingTeachers = ref<TeacherAuditItem[]>([])

// ---------- 最近敏感操作 ----------
const recentLogs = ref<AuditLogItem[]>([])

const stats = computed(() => {
  if (!dashboardData.value) return []
  const d = dashboardData.value
  return [
    { label: '今日活跃学生', value: d.todayActiveStudents, detail: '今日登录并参与学习' },
    { label: '认证教师', value: d.activeTeachers, detail: '已通过资质审核' },
    { label: '问诊会话', value: d.chatSessionCount, detail: '累计 AI 问诊会话' },
    { label: '作业提交', value: d.assignmentSubmitCount, detail: '累计学生作业提交' },
    { label: '待审病例', value: d.pendingCaseAuditCount, detail: '等待审核的病例' },
    { label: '待审教师', value: d.pendingTeacherAuditCount, detail: '等待资质审核' },
    { label: '官方病例', value: d.officialCaseCount, detail: '已发布认证病例' },
  ]
})

async function fetchDashboard(): Promise<void> {
  loading.value = true
  try {
    dashboardData.value = await getDashboard()
    // 并行加载待办审核与最近敏感操作（真实数据）
    const [teacherPage, casePage, logPage] = await Promise.all([
      listTeacherAudits(1, 5, 1),
      listCaseAudits(1, 5),
      listAuditLogs(1, 5),
    ])
    pendingTeachers.value = teacherPage.list ?? []
    pendingCases.value = casePage.list ?? []
    recentLogs.value = logPage.list ?? []
  } catch {
    // http.ts 已处理错误提示
  } finally {
    loading.value = false
  }
}

async function fetchUserStats(): Promise<void> {
  statsLoading.value = true
  try {
    const [ov, ot, rt, at] = await Promise.all([
      getUserOverview(),
      getOnlineTrend(),
      getRegisterTrend(30),
      getActiveTrend(30),
    ])
    overview.value = ov
    onlineTrend.value = ot
    registerTrend.value = rt
    activeTrend.value = at
    await nextTick()
    renderCharts()
  } catch {
    // http.ts 已处理错误提示
  } finally {
    statsLoading.value = false
  }
}

/** 渲染两张趋势折线图 */
function renderCharts(): void {
  if (onlineChartEl.value) {
    if (!onlineChart) {
      onlineChart = echarts.init(onlineChartEl.value)
    }
    onlineChart.setOption(buildOnlineOption(), true)
  }
  if (trendChartEl.value) {
    if (!trendChart) {
      trendChart = echarts.init(trendChartEl.value)
    }
    trendChart.setOption(buildTrendOption(), true)
  }
}

/** 今日在线走势折线图配置 */
function buildOnlineOption(): echarts.EChartsCoreOption {
  const labels = onlineTrend.value.map((p) => p.label)
  return {
    tooltip: { trigger: 'axis' },
    legend: { data: ['总在线', '学生', '教师'], top: 0 },
    grid: { left: 40, right: 16, top: 36, bottom: 28 },
    xAxis: { type: 'category', data: labels, boundaryGap: false },
    yAxis: { type: 'value', minInterval: 1 },
    series: [
      {
        name: '总在线',
        type: 'line',
        smooth: true,
        symbol: 'none',
        data: onlineTrend.value.map((p) => p.total ?? 0),
        lineStyle: { width: 3, color: COLOR_TOTAL },
        itemStyle: { color: COLOR_TOTAL },
        areaStyle: {
          color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: 'rgba(15, 76, 92, 0.28)' },
            { offset: 1, color: 'rgba(15, 76, 92, 0.02)' },
          ]),
        },
      },
      {
        name: '学生',
        type: 'line',
        smooth: true,
        symbol: 'none',
        data: onlineTrend.value.map((p) => p.students ?? 0),
        lineStyle: { width: 2, color: COLOR_STUDENT },
        itemStyle: { color: COLOR_STUDENT },
      },
      {
        name: '教师',
        type: 'line',
        smooth: true,
        symbol: 'none',
        data: onlineTrend.value.map((p) => p.teachers ?? 0),
        lineStyle: { width: 2, type: 'dashed', color: COLOR_TEACHER },
        itemStyle: { color: COLOR_TEACHER },
      },
    ],
  }
}

/** 近 30 天活跃与新增注册折线图配置 */
function buildTrendOption(): echarts.EChartsCoreOption {
  const labels = activeTrend.value.map((p) => p.label)
  return {
    tooltip: { trigger: 'axis' },
    legend: { data: ['日活跃用户', '峰值在线', '新增注册'], top: 0 },
    grid: { left: 40, right: 16, top: 36, bottom: 28 },
    xAxis: { type: 'category', data: labels, boundaryGap: false },
    yAxis: { type: 'value', minInterval: 1 },
    series: [
      {
        name: '日活跃用户',
        type: 'line',
        smooth: true,
        symbol: 'none',
        data: activeTrend.value.map((p) => p.total ?? 0),
        lineStyle: { width: 3, color: COLOR_TOTAL },
        itemStyle: { color: COLOR_TOTAL },
        areaStyle: {
          color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: 'rgba(15, 76, 92, 0.24)' },
            { offset: 1, color: 'rgba(15, 76, 92, 0.02)' },
          ]),
        },
      },
      {
        name: '峰值在线',
        type: 'line',
        smooth: true,
        symbol: 'none',
        data: activeTrend.value.map((p) => p.students ?? 0),
        lineStyle: { width: 2, color: COLOR_STUDENT },
        itemStyle: { color: COLOR_STUDENT },
      },
      {
        name: '新增注册',
        type: 'line',
        smooth: true,
        symbol: 'circle',
        symbolSize: 5,
        data: registerTrend.value.map((p) => p.newUsers ?? 0),
        lineStyle: { width: 2, type: 'dashed', color: COLOR_TEACHER },
        itemStyle: { color: COLOR_TEACHER },
      },
    ],
  }
}

function handleResize(): void {
  onlineChart?.resize()
  trendChart?.resize()
}

const formatTime = (iso: string | null) => fmtDateTime(iso)

/** 合并待审教师与待审病例，渲染到「待办审核」面板 */
const pendingItems = computed(() => {
  const items: { id: string; title: string; meta: string; type: 'teacher' | 'case' }[] = []
  for (const t of pendingTeachers.value) {
    items.push({
      id: `t-${t.userId}`,
      title: `教师入驻 · ${t.realName || t.username}`,
      meta: `${t.phone || '-'} · ${t.department || '未填科室'}`,
      type: 'teacher',
    })
  }
  for (const c of pendingCases.value) {
    items.push({
      id: `c-${c.caseId}`,
      title: `病例 · ${c.title}`,
      meta: `${c.creatorName || '-'} · ${c.department || '-'}`,
      type: 'case',
    })
  }
  return items
})

onMounted(() => {
  fetchDashboard()
  fetchUserStats()
  window.addEventListener('resize', handleResize)
})

onBeforeUnmount(() => {
  window.removeEventListener('resize', handleResize)
  onlineChart?.dispose()
  trendChart?.dispose()
  onlineChart = null
  trendChart = null
})
</script>

<template>
  <main class="admin-page">
    <section class="admin-page-head">
      <div>
        <span>全局驾驶舱</span>
        <h1>平台运行与教学运营总览</h1>
      </div>
      <el-button :loading="loading" plain @click="fetchDashboard">刷新数据</el-button>
    </section>

    <!-- 统计卡片：真实数据 -->
    <section v-loading="loading" class="stats-grid">
      <article
        v-for="item in stats"
        :key="item.label"
        class="surface-card stat-card interactive"
      >
        <span>{{ item.label }}</span>
        <strong>{{ item.value }}</strong>
        <p>{{ item.detail }}</p>
      </article>
      <article v-if="stats.length === 0 && !loading" class="surface-card stat-card">
        <span>暂无数据</span>
      </article>
    </section>

    <!-- 用户数据看板：注册 · 活跃 · 在线 -->
    <section class="admin-page-head dashboard-sub-head">
      <div>
        <span>用户数据看板</span>
        <h1>注册 · 活跃 · 在线趋势</h1>
      </div>
      <el-button :loading="statsLoading" plain @click="fetchUserStats">刷新看板</el-button>
    </section>

    <section v-loading="statsLoading" class="stats-grid">
      <article
        v-for="item in userStats"
        :key="item.label"
        class="surface-card stat-card interactive"
      >
        <span>{{ item.label }}</span>
        <strong>{{ item.value }}</strong>
        <p>{{ item.detail }}</p>
      </article>
      <article v-if="userStats.length === 0 && !statsLoading" class="surface-card stat-card">
        <span>暂无数据</span>
      </article>
    </section>

    <section class="chart-grid">
      <article class="surface-card panel">
        <div class="panel-head">
          <div class="panel-title">
            <h2 class="admin-section-title">今日在线人数走势</h2>
          </div>
          <el-tag size="small" effect="plain">每 5 分钟采样</el-tag>
        </div>
        <div v-if="onlineTrend.length > 0" ref="onlineChartEl" class="chart-box" />
        <div v-else-if="!statsLoading" class="empty-row">
          暂无今日采样数据 · 系统每 5 分钟自动记录在线人数，上线后逐渐积累
        </div>
      </article>

      <article class="surface-card panel">
        <div class="panel-head">
          <div class="panel-title">
            <h2 class="admin-section-title">近 30 天活跃与新增注册</h2>
          </div>
        </div>
        <div ref="trendChartEl" class="chart-box" />
      </article>
    </section>

    <!-- 待办审核 & 最近敏感操作：真实数据 -->
    <section class="dashboard-grid">
      <article class="surface-card panel">
        <div class="panel-head">
          <div class="panel-title">
            <h2 class="admin-section-title">待办审核</h2>
          </div>
          <el-tag type="danger" effect="plain">{{ pendingItems.length }} 项</el-tag>
        </div>
        <div v-loading="loading" min-height="80">
          <div v-for="item in pendingItems" :key="item.id" class="list-row">
            <div>
              <strong>{{ item.title }}</strong>
              <span>{{ item.meta }}</span>
            </div>
            <el-tag
              size="small"
              :type="item.type === 'teacher' ? 'warning' : 'primary'"
              effect="plain"
            >
              {{ item.type === 'teacher' ? '教师' : '病例' }}
            </el-tag>
          </div>
          <div v-if="!loading && pendingItems.length === 0" class="empty-row">暂无待办审核</div>
        </div>
      </article>

      <article class="surface-card panel">
        <div class="panel-head">
          <div class="panel-title">
            <h2 class="admin-section-title">最近敏感操作</h2>
          </div>
        </div>
        <div v-loading="loading" min-height="80">
          <div v-for="item in recentLogs" :key="item.id" class="list-row">
            <div>
              <strong>{{ item.action }}</strong>
              <span>{{ formatTime(item.createdAt) }} · {{ item.operatorName || '-' }} · {{ item.targetType || '-' }}</span>
            </div>
          </div>
          <div v-if="!loading && recentLogs.length === 0" class="empty-row">暂无审计日志</div>
        </div>
      </article>
    </section>
  </main>
</template>

<style scoped>
.empty-row {
  padding: 24px 0;
  color: var(--zy-muted);
  font-size: 13px;
  font-weight: 800;
  text-align: center;
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 16px;
}

.stat-card,
.panel {
  padding: 20px;
}

.stat-card span,
.stat-card p,
.list-row span {
  color: var(--zy-muted);
  font-size: 13px;
  font-weight: 800;
}

.stat-card strong {
  display: block;
  margin-top: 10px;
  color: var(--zy-ink);
  font-size: 34px;
}

.stat-card p {
  margin: 8px 0 0;
}

.dashboard-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}

.dashboard-sub-head {
  margin-top: 28px;
}

.chart-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}

.chart-box {
  width: 100%;
  height: 320px;
}

.panel-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
  margin-bottom: 8px;
}

.panel-title {
  display: flex;
  align-items: center;
  gap: 8px;
}

.panel-head a {
  color: var(--zy-brand-strong);
  font-size: 13px;
  font-weight: 800;
  text-decoration: none;
}

.list-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 16px 0;
  border-top: 1px solid var(--zy-line);
}

.list-row strong,
.list-row span {
  display: block;
}

.list-row strong {
  color: var(--zy-ink);
}

@media (max-width: 1100px) {
  .stats-grid,
  .dashboard-grid,
  .chart-grid {
    grid-template-columns: 1fr 1fr;
  }
}

@media (max-width: 760px) {
  .stats-grid,
  .dashboard-grid,
  .chart-grid {
    grid-template-columns: 1fr;
  }
}
</style>
