<script setup lang="ts">
import { computed } from 'vue'
import { useUserStore } from '@/stores/user'
import { assignments, cases, dailyCase, heatmapDays, mistakes, reviewQueue, weakness } from './mockData'

const user = useUserStore()
const isTeacher = computed(() => user.role === 1)
const pendingReviews = computed(() => reviewQueue.filter((item) => item.status !== '已复核').length)
const completionRate = computed(() => {
  const submitted = assignments.reduce((sum, item) => sum + item.submitted, 0)
  const total = assignments.reduce((sum, item) => sum + item.total, 0)
  return Math.round((submitted / total) * 100)
})

const studentTasks = computed(() => [
  { title: '完成每日一例', detail: dailyCase.title, path: '/student/daily' },
  { title: '继续问诊训练', detail: cases[1].title, path: `/student/chat?caseId=${cases[1].id}` },
  { title: '提交大病历', detail: '胸痛鉴别诊断', path: '/student/record' },
  { title: '错题复盘', detail: `${mistakes.length} 个待巩固问题`, path: '/student/mistakes' }
])

const teacherTasks = computed(() => [
  { title: '复核批阅结果', detail: `${pendingReviews.value} 份待处理`, path: '/teacher/review' },
  { title: '查看作业进度', detail: `${completionRate.value}% 已提交`, path: '/teacher/assignments' },
  { title: '配置新病例', detail: '胸痛伴气促', path: '/teacher/cases' }
])
</script>

<template>
  <main class="page-shell">
    <section class="page-head hero-head">
      <div>
        <span>{{ isTeacher ? '教学概览' : '今日训练' }}</span>
        <h1>
          {{ isTeacher ? '查看班级训练进度与需要人工确认的结果' : '从一个病例开始，完成今天的临床推理练习' }}
        </h1>
        <p>
          {{ isTeacher ? '聚合提交进度、待复核任务和高频薄弱点，帮助你安排下一次教学。' : '系统会记录问诊路径、检查成本和诊断依据，训练结束后生成可复盘反馈。' }}
        </p>
      </div>
      <div class="hero-actions">
        <router-link class="primary-link" :to="isTeacher ? '/teacher/review' : '/student/daily'">
          {{ isTeacher ? '查看待复核' : '进入每日一例' }}
        </router-link>
        <router-link class="secondary-link" :to="isTeacher ? '/teacher/assignments' : '/student/cases'">
          {{ isTeacher ? '分发作业' : '选择病例' }}
        </router-link>
      </div>
    </section>

    <section class="overview-grid">
      <article class="surface-card stat-card interactive">
        <span>{{ isTeacher ? '提交进度' : '可训练病例' }}</span>
        <strong>{{ isTeacher ? `${completionRate}%` : cases.length }}</strong>
        <p>{{ isTeacher ? '按当前作业统计，适合优先跟进未提交学生。' : '覆盖呼吸、心血管、消化系统，支持问诊和诊断练习。' }}</p>
      </article>
      <article class="surface-card stat-card interactive">
        <span>{{ isTeacher ? '待复核' : '今日重点' }}</span>
        <strong>{{ isTeacher ? pendingReviews : '问诊路径' }}</strong>
        <p>{{ isTeacher ? '保留人工最终判断，避免 AI 批阅误伤关键推理。' : '练习追问症状演变、危险信号和必要检查。' }}</p>
      </article>
      <article class="surface-card stat-card interactive">
        <span>{{ isTeacher ? '高频薄弱点' : '最近反馈' }}</span>
        <strong>{{ isTeacher ? weakness[0].tag : '68' }}</strong>
        <p>{{ isTeacher ? '建议安排针对性补救病例和课堂讲评。' : '诊断逻辑仍可提升，建议完成胸痛鉴别切片。' }}</p>
      </article>
    </section>

    <section v-if="!isTeacher" class="surface-card habit-card">
      <div class="section-head">
        <h2>学习热力图</h2>
        <router-link to="/student/daily">进入每日一例</router-link>
      </div>
      <div class="mini-heatmap" aria-label="最近学习热力图">
        <span
          v-for="day in heatmapDays.slice(-42)"
          :key="day.date"
          class="heat-cell"
          :class="`level-${day.value}`"
        />
      </div>
    </section>

    <section class="content-grid">
      <article class="surface-card task-card">
        <div class="section-head">
          <h2>待办</h2>
        </div>
        <router-link
          v-for="item in isTeacher ? teacherTasks : studentTasks"
          :key="item.title"
          class="task-row"
          :to="item.path"
        >
          <span>
            <strong>{{ item.title }}</strong>
            <small>{{ item.detail }}</small>
          </span>
          <el-icon><ArrowRight /></el-icon>
        </router-link>
      </article>

      <article class="surface-card task-card">
        <div class="section-head">
          <h2>{{ isTeacher ? '班级常错点' : '最近病例' }}</h2>
        </div>
        <div v-if="isTeacher" class="simple-list">
          <div v-for="item in weakness" :key="item.tag">
            <strong>{{ item.tag }}</strong>
            <span>{{ Math.round(item.avg * 100) }}% 平均掌握 · {{ item.count }} 次训练</span>
          </div>
        </div>
        <div v-else class="simple-list">
          <div v-for="item in cases" :key="item.title">
            <strong>{{ item.title }}</strong>
            <span>{{ item.duration }} · {{ item.difficulty }} · {{ item.department }}</span>
          </div>
        </div>
      </article>
    </section>
  </main>
</template>

<style scoped>
.hero-head p {
  max-width: 680px;
  margin: 12px 0 0;
  color: var(--zy-muted);
  line-height: 1.75;
}

.hero-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.primary-link,
.secondary-link {
  display: inline-flex;
  align-items: center;
  min-height: 42px;
  padding: 0 16px;
  border-radius: 14px;
  font-weight: 800;
  text-decoration: none;
}

.primary-link {
  background: var(--zy-brand);
  color: #fff;
}

.secondary-link {
  border: 1px solid var(--zy-line);
  background: #fff;
  color: var(--zy-brand-strong);
}

.overview-grid,
.content-grid {
  display: grid;
  gap: 16px;
}

.overview-grid {
  grid-template-columns: 1fr 1fr 1.2fr;
}

.content-grid {
  grid-template-columns: 1fr 1fr;
}

.stat-card,
.task-card,
.habit-card {
  padding: 20px;
}

.stat-card span {
  display: block;
  color: var(--zy-muted);
  font-size: 13px;
  font-weight: 800;
}

.stat-card strong {
  display: block;
  margin-top: 10px;
  color: var(--zy-ink);
  font-size: 42px;
  line-height: 1;
}

.stat-card p {
  margin: 10px 0 0;
  color: var(--zy-muted);
  line-height: 1.65;
}

.section-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
}

.section-head h2 {
  margin: 0 0 14px;
  color: var(--zy-ink);
  font-size: 20px;
}

.section-head a {
  color: var(--zy-brand-strong);
  font-size: 13px;
  font-weight: 800;
  text-decoration: none;
}

.task-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 14px 0;
  border-bottom: 1px solid var(--zy-line);
  color: inherit;
  text-decoration: none;
}

.task-row:last-child {
  border-bottom: 0;
}

.task-row strong,
.task-row small,
.simple-list strong,
.simple-list span {
  display: block;
}

.task-row strong,
.simple-list strong {
  color: var(--zy-ink);
}

.task-row small,
.simple-list span {
  margin-top: 4px;
  color: var(--zy-muted);
  font-size: 13px;
  font-weight: 700;
}

.simple-list {
  display: grid;
  gap: 14px;
}

.mini-heatmap {
  display: grid;
  grid-template-columns: repeat(21, 1fr);
  gap: 7px;
}

.heat-cell {
  aspect-ratio: 1;
  border-radius: 6px;
  background: rgba(15, 76, 92, 0.08);
}

.level-1 {
  background: rgba(15, 76, 92, 0.22);
}

.level-2 {
  background: rgba(15, 76, 92, 0.38);
}

.level-3 {
  background: rgba(15, 76, 92, 0.62);
}

.level-4 {
  background: var(--zy-brand);
}

@media (max-width: 980px) {
  .overview-grid,
  .content-grid {
    grid-template-columns: 1fr;
  }
}
</style>
