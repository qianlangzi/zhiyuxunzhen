<script setup lang="ts">
import { weakness } from '../mockData'
</script>

<template>
  <main class="page-shell">
    <section class="page-head">
      <span>班级常错点</span>
      <h1>查看班级常错点</h1>
    </section>

    <section class="weakness-grid">
      <article v-for="item in weakness" :key="item.tag" class="surface-card weakness-card">
        <div>
          <strong>{{ item.tag }}</strong>
          <span>{{ item.count }} 次相关训练</span>
        </div>
        <el-progress :percentage="Math.round(item.avg * 100)" />
        <p>平均掌握度 {{ Math.round(item.avg * 100) }}%，建议安排补救病例。</p>
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
}

.weakness-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 14px;
}

.weakness-card {
  display: grid;
  gap: 12px;
  padding: 16px;
}

.weakness-card strong,
.weakness-card span {
  display: block;
}

.weakness-card span,
.weakness-card p {
  color: var(--zy-muted);
}

.weakness-card p {
  margin: 0;
  line-height: 1.6;
}

@media (max-width: 1180px) {
  .weakness-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 720px) {
  .weakness-grid {
    grid-template-columns: 1fr;
  }
}
</style>
