<script setup lang="ts">
import { useUserStore } from '@/stores/user'
import { assignments, cases, dailyCase, heatmapDays, mistakes, reviewQueue, weakness } from './mockData'
import { computed } from 'vue'

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
    <section class="page-head">
      <div>
        <span>{{ isTeacher ? '教学概览' : '今日训练' }}</span>
        <h1>{{ isTeacher ? '今天需要关注的教学进度' : '今天继续一段训练' }}</h1>
      </div>
    </section>

    <section class="overview-grid">
      <article class="surface-card stat-card">
        <span>{{ isTeacher ? '提交进度' : '可训练病例' }}</span>
        <strong>{{ isTeacher ? `${completionRate}%` : cases.length }}</strong>
        <p>{{ isTeacher ? '按当前作业统计' : '覆盖呼吸、心血管、消化系统' }}</p>
      </article>
      <article class="surface-card stat-card">
        <span>{{ isTeacher ? '待复核' : '下一步' }}</span>
        <strong>{{ isTeacher ? pendingReviews : '问诊' }}</strong>
        <p>{{ isTeacher ? '保留人工最终判断' : '进入模拟病人对话室' }}</p>
      </article>
      <article class="surface-card stat-card">
        <span>{{ isTeacher ? '常错主题' : '最近反馈' }}</span>
        <strong>{{ isTeacher ? weakness[0].tag : '68' }}</strong>
        <p>{{ isTeacher ? '建议安排针对性练习' : '诊断逻辑，还可继续练习' }}</p>
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
            <span>{{ Math.round(item.avg * 100) }}% · {{ item.count }} 次训练</span>
          </div>
        </div>
        <div v-else class="simple-list">
          <div v-for="item in cases" :key="item.title">
            <strong>{{ item.title }}</strong>
            <span>{{ item.duration }} · {{ item.difficulty }}</span>
          </div>
        </div>
      </article>
    </section>
  </main>
</template>

<style scoped>
.page-shell {
  display: grid;
  gap: 20px;
}

.page-head {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 16px;
}

.page-head span,
.stat-card span {
  display: block;
  color: var(--zy-muted);
  font-size: 13px;
  font-weight: 800;
}

.page-head h1 {
  margin: 6px 0 0;
  color: var(--zy-ink);
  font-size: clamp(26px, 3vw, 34px);
  line-height: 1.1;
  letter-spacing: 0;
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
}

.section-head h2 {
  margin: 0 0 14px;
  color: var(--zy-ink);
  font-size: 20px;
}

.section-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
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
  border-radius: 4px;
  background: rgba(15, 118, 110, 0.08);
}

.level-1 {
  background: rgba(15, 118, 110, 0.22);
}

.level-2 {
  background: rgba(15, 118, 110, 0.38);
}

.level-3 {
  background: rgba(15, 118, 110, 0.62);
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

@media (max-width: 680px) {
  .page-head {
    align-items: flex-start;
    flex-direction: column;
  }
}
</style>
