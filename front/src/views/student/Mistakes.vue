<script setup lang="ts">
import { computed, ref } from 'vue'
import { mistakes } from '../mockData'

const activeType = ref('全部')
const options = ['全部', '诊断错误', '漏问病史', '检查错误']

const filteredMistakes = computed(() => {
  if (activeType.value === '全部') return mistakes
  return mistakes.filter((item) => item.type === activeType.value)
})
</script>

<template>
  <main class="mistake-page">
    <section class="page-head">
      <div>
        <span>错题复盘</span>
        <h1>把每一次脱轨变成下一次的路径</h1>
      </div>
      <el-button type="primary">导出 AI 复盘报告</el-button>
    </section>

    <section class="summary-grid">
      <article class="surface-card summary-card">
        <span>未复习错题</span>
        <strong>{{ mistakes.filter((item) => item.status === '未复习').length }}</strong>
        <p>建议优先处理胸痛鉴别与检查成本意识。</p>
      </article>
      <article class="surface-card summary-card">
        <span>高频薄弱点</span>
        <strong>心衰</strong>
        <p>连续 3 次在夜间憋醒、端坐呼吸追问上扣分。</p>
      </article>
      <article class="surface-card summary-card">
        <span>报告范围</span>
        <strong>近 30 天</strong>
        <p>包含诊断错误、漏问病史、文书问题和过度检查。</p>
      </article>
    </section>

    <section class="surface-card list-panel">
      <div class="list-head">
        <h2>错题列表</h2>
        <el-segmented v-model="activeType" :options="options" />
      </div>

      <article v-for="item in filteredMistakes" :key="item.title" class="mistake-row">
        <div>
          <el-tag effect="plain">{{ item.type }}</el-tag>
          <strong>{{ item.title }}</strong>
          <p>{{ item.evidence }}</p>
        </div>
        <div class="row-side">
          <span>{{ item.tag }}</span>
          <el-button plain>{{ item.status === '未复习' ? '开始复盘' : '查看记录' }}</el-button>
        </div>
      </article>
    </section>
  </main>
</template>

<style scoped>
.mistake-page {
  display: grid;
  gap: 20px;
}

.summary-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 16px;
}

.summary-card,
.list-panel {
  padding: 20px;
}

.summary-card span,
.row-side span {
  display: block;
  color: var(--zy-muted);
  font-size: 13px;
  font-weight: 800;
}

.summary-card strong {
  display: block;
  margin-top: 10px;
  color: var(--zy-ink);
  font-size: 28px;
}

.summary-card p,
.mistake-row p {
  margin: 8px 0 0;
  color: var(--zy-muted);
  line-height: 1.65;
}

.list-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 8px;
}

.list-head h2 {
  margin: 0;
  color: var(--zy-ink);
  font-size: 22px;
}

.mistake-row {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 180px;
  gap: 18px;
  align-items: center;
  padding: 18px 0;
  border-top: 1px solid var(--zy-line);
}

.mistake-row strong {
  display: block;
  margin-top: 10px;
  color: var(--zy-ink);
}

.row-side {
  display: grid;
  justify-items: end;
  gap: 10px;
}

@media (max-width: 980px) {
  .summary-grid,
  .mistake-row {
    grid-template-columns: 1fr;
  }

  .list-head {
    align-items: flex-start;
    flex-direction: column;
  }

  .row-side {
    justify-items: start;
  }
}
</style>
