<script setup lang="ts">
import { useRouter } from 'vue-router'
import { cases } from '../mockData'

const router = useRouter()

function enterTraining(caseId: string) {
  router.push({ path: '/student/chat', query: { caseId } })
}
</script>

<template>
  <main class="page-shell">
    <section class="page-head">
      <span>选择病例</span>
      <h1>选择一个模拟病人开始训练</h1>
    </section>

    <section class="case-grid">
      <article v-for="item in cases" :key="item.title" class="surface-card case-card">
        <div>
          <strong>{{ item.title }}</strong>
          <span>{{ item.difficulty }} · {{ item.duration }}</span>
        </div>
        <p>{{ item.chief }}</p>
        <div class="tag-row">
          <el-tag v-for="tag in item.tags" :key="tag" effect="plain">{{ tag }}</el-tag>
        </div>
        <el-button type="primary" @click="enterTraining(item.id)">进入问诊室</el-button>
      </article>
    </section>
  </main>
</template>

<style scoped>
.page-shell {
  display: grid;
  gap: 20px;
}

.page-head span {
  color: var(--zy-muted);
  font-size: 13px;
  font-weight: 800;
}

.page-head h1 {
  margin: 6px 0 0;
  color: var(--zy-ink);
  font-size: clamp(26px, 3vw, 34px);
  line-height: 1.12;
}

.case-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 16px;
}

.case-card {
  display: grid;
  align-content: start;
  gap: 16px;
  min-height: 260px;
  padding: 20px;
}

.case-card strong,
.case-card span {
  display: block;
}

.case-card strong {
  color: var(--zy-ink);
  font-size: 18px;
}

.case-card span,
.case-card p {
  color: var(--zy-muted);
}

.case-card p {
  margin: 0;
  line-height: 1.7;
}

.tag-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

@media (max-width: 1180px) {
  .case-grid {
    grid-template-columns: 1fr;
  }
}
</style>
