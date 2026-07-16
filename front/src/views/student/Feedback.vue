<script setup lang="ts">
import { abilityScores, learningPath } from '../mockData'
</script>

<template>
  <main class="page-shell">
    <section class="page-head">
      <div>
        <span>能力反馈</span>
        <h1>查看本次训练反馈和下一步练习</h1>
      </div>
    </section>

    <section class="feedback-grid">
      <article class="surface-card panel">
        <h2>临床能力四维评估</h2>
        <div v-for="score in abilityScores" :key="score.label" class="score-row">
          <span>{{ score.label }}</span>
          <el-progress :percentage="score.value" :stroke-width="10" :show-text="false" />
          <strong>{{ score.value }}</strong>
        </div>
      </article>

      <article class="surface-card panel">
        <h2>建议练习</h2>
        <article v-for="path in learningPath" :key="path.title" class="path-item">
          <div>
            <strong>{{ path.title }}</strong>
            <span>{{ path.meta }}</span>
          </div>
          <el-progress type="circle" :percentage="path.progress" :width="48" />
        </article>
      </article>
    </section>
  </main>
</template>

<style scoped>
.feedback-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}

.panel {
  padding: 20px;
}

h2 {
  margin: 0 0 18px;
  color: var(--zy-ink);
  font-size: 22px;
}

.score-row {
  display: grid;
  grid-template-columns: 92px minmax(0, 1fr) 42px;
  gap: 12px;
  align-items: center;
  margin-top: 16px;
}

.score-row span,
.path-item span {
  color: var(--zy-muted);
  font-size: 13px;
  font-weight: 800;
}

.path-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
  padding: 14px 0;
  border-bottom: 1px solid var(--zy-line);
}

.path-item:last-child {
  border-bottom: 0;
}

.path-item strong,
.path-item span {
  display: block;
}

@media (max-width: 900px) {
  .feedback-grid,
  .score-row {
    grid-template-columns: 1fr;
  }
}
</style>
