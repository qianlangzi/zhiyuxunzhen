<script setup lang="ts">
import { computed, ref } from 'vue'
import { ElMessage } from 'element-plus'
import { reviewQueue } from '../mockData'

const selectedReviewId = ref(1)
const selectedReview = computed(() => {
  return reviewQueue.find((item) => item.id === selectedReviewId.value) || reviewQueue[0]
})

function confirmReview(action: string) {
  ElMessage.success(`${action}：${selectedReview.value.student}`)
}
</script>

<template>
  <main class="review-page">
    <section class="page-head">
      <div>
        <span>批阅复核</span>
        <h1>处理智能批阅结果</h1>
      </div>
    </section>

    <section class="review-grid">
      <article class="surface-card list-panel">
        <button
          v-for="item in reviewQueue"
          :key="item.id"
          class="review-item"
          :class="{ active: selectedReviewId === item.id }"
          type="button"
          @click="selectedReviewId = item.id"
        >
          <span>
            <strong>{{ item.student }}</strong>
            <small>{{ item.assignment }}</small>
          </span>
          <em>{{ item.score }}</em>
        </button>
      </article>

      <aside class="surface-card detail-panel">
        <div class="detail-head">
          <span>{{ selectedReview.status }}</span>
          <strong>{{ selectedReview.score }} 分</strong>
        </div>
        <h2>{{ selectedReview.student }} · {{ selectedReview.assignment }}</h2>
        <p>{{ selectedReview.issue }}</p>
        <div class="note">
          <span>建议关注</span>
          <strong>核心检查项缺失，建议补充心电图与肌钙蛋白，并确认疼痛放射方向。</strong>
        </div>
        <div class="actions">
          <el-button @click="confirmReview('标记申诉')">标记申诉</el-button>
          <el-button plain @click="confirmReview('退回修改')">退回修改</el-button>
          <el-button type="primary" @click="confirmReview('确认复核')">确认复核</el-button>
        </div>
      </aside>
    </section>
  </main>
</template>

<style scoped>
.review-page {
  display: grid;
  gap: 20px;
}

.review-grid {
  display: grid;
  grid-template-columns: minmax(280px, 0.8fr) minmax(0, 1.1fr);
  gap: 16px;
}

.list-panel,
.detail-panel {
  padding: 18px;
}

.review-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  width: 100%;
  padding: 16px;
  border: 1px solid var(--zy-line);
  border-radius: 18px;
  background: rgba(255, 255, 255, 0.66);
  color: var(--zy-ink);
  cursor: pointer;
  text-align: left;
}

.review-item + .review-item {
  margin-top: 12px;
}

.review-item.active {
  border-color: rgba(15, 76, 92, 0.38);
  background: var(--zy-brand-soft);
}

.review-item strong,
.review-item small {
  display: block;
}

.review-item small {
  color: var(--zy-muted);
  font-size: 13px;
  font-weight: 800;
}

.review-item em {
  color: var(--zy-brand-strong);
  font-size: 24px;
  font-style: normal;
  font-weight: 900;
}

.detail-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.detail-head span {
  padding: 7px 10px;
  border-radius: 999px;
  background: var(--zy-brand-soft);
  color: var(--zy-brand-strong);
  font-size: 12px;
  font-weight: 900;
}

.detail-head strong {
  color: var(--zy-ink);
  font-size: 34px;
}

h2 {
  margin: 18px 0 0;
  color: var(--zy-ink);
}

p {
  color: var(--zy-muted);
  line-height: 1.7;
}

.note {
  margin: 18px 0;
  padding: 16px;
  border-radius: 16px;
  background: rgba(194, 65, 58, 0.08);
}

.note span,
.note strong {
  display: block;
}

.note span {
  color: var(--zy-danger);
  font-size: 13px;
  font-weight: 900;
}

.note strong {
  margin-top: 6px;
  color: var(--zy-ink);
  line-height: 1.6;
}

.actions {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 10px;
}

@media (max-width: 980px) {
  .review-grid {
    grid-template-columns: 1fr;
  }
}
</style>
