<script setup lang="ts">
import { computed, ref } from 'vue'
import { dailyCase, heatmapDays } from '../mockData'

const selectedDiagnosis = ref('')
const selectedRequiredExam = ref('')
const selectedAvoidExam = ref('')
const submitted = ref(false)

const completedDays = computed(() => heatmapDays.filter((day) => day.value > 0).length)

function submitDailyCase() {
  submitted.value = true
}
</script>

<template>
  <main class="daily-page">
    <section class="page-head">
      <div>
        <span>每日一例</span>
        <h1>5 分钟完成一次临床判断</h1>
      </div>
      <el-tag effect="plain">{{ completedDays }} 天有训练记录</el-tag>
    </section>

    <section class="daily-grid">
      <article class="surface-card case-panel">
        <div class="case-title">
          <span>今日病例</span>
          <h2>{{ dailyCase.title }}</h2>
        </div>
        <p>{{ dailyCase.summary }}</p>

        <div class="field-block">
          <strong>最可能诊断</strong>
          <el-radio-group v-model="selectedDiagnosis">
            <el-radio-button v-for="option in dailyCase.options" :key="option" :label="option" />
          </el-radio-group>
        </div>

        <div class="decision-grid">
          <label class="decision-box">
            <span>必须补充的检查</span>
            <el-select v-model="selectedRequiredExam" placeholder="选择检查">
              <el-option label="心电图" value="心电图" />
              <el-option label="胃镜" value="胃镜" />
              <el-option label="胸部增强 CT" value="胸部增强 CT" />
            </el-select>
          </label>
          <label class="decision-box">
            <span>应避免的检查</span>
            <el-select v-model="selectedAvoidExam" placeholder="选择检查">
              <el-option label="无指征胸部增强 CT" value="无指征胸部增强 CT" />
              <el-option label="心电图" value="心电图" />
              <el-option label="肌钙蛋白" value="肌钙蛋白" />
            </el-select>
          </label>
        </div>

        <el-button type="primary" :disabled="!selectedDiagnosis" @click="submitDailyCase">提交今日判断</el-button>

        <div v-if="submitted" class="result-box" role="status">
          <strong>反馈</strong>
          <p>标准诊断倾向：{{ dailyCase.options[0] }}。必要检查：{{ dailyCase.requiredExam }}。应避免：{{ dailyCase.avoidExam }}。</p>
          <small>{{ dailyCase.source }}</small>
        </div>
      </article>

      <aside class="surface-card heatmap-panel">
        <div class="case-title">
          <span>学习热力图</span>
          <h2>最近 12 周</h2>
        </div>
        <div class="heatmap" aria-label="最近 12 周学习热力图">
          <span
            v-for="day in heatmapDays"
            :key="day.date"
            class="heat-cell"
            :class="`level-${day.value}`"
            :title="`${day.date}: ${day.value} 次训练`"
          />
        </div>
        <div class="legend">
          <span>少</span>
          <i class="heat-cell level-1" />
          <i class="heat-cell level-2" />
          <i class="heat-cell level-3" />
          <i class="heat-cell level-4" />
          <span>多</span>
        </div>
      </aside>
    </section>
  </main>
</template>

<style scoped>
.daily-page {
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
.case-title span,
.decision-box span {
  display: block;
  color: var(--zy-muted);
  font-size: 13px;
  font-weight: 800;
}

.page-head h1,
.case-title h2 {
  margin: 6px 0 0;
  color: var(--zy-ink);
  line-height: 1.12;
}

.page-head h1 {
  font-size: clamp(26px, 3vw, 34px);
}

.case-title h2 {
  font-size: 22px;
}

.daily-grid {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 360px;
  gap: 16px;
}

.case-panel,
.heatmap-panel {
  padding: 20px;
}

.case-panel {
  display: grid;
  gap: 18px;
}

.case-panel p {
  margin: 0;
  color: var(--zy-muted);
  line-height: 1.75;
}

.field-block {
  display: grid;
  gap: 10px;
}

.field-block strong {
  color: var(--zy-ink);
}

.decision-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 14px;
}

.decision-box {
  display: grid;
  gap: 8px;
}

.result-box {
  padding: 14px;
  border: 1px solid rgba(15, 118, 110, 0.24);
  border-radius: var(--zy-radius-md);
  background: var(--zy-brand-soft);
}

.result-box strong,
.result-box small {
  display: block;
}

.result-box small {
  color: var(--zy-brand-strong);
  font-weight: 800;
}

.heatmap {
  display: grid;
  grid-auto-flow: column;
  grid-template-rows: repeat(7, 14px);
  gap: 7px;
  margin-top: 20px;
  overflow-x: auto;
  padding-bottom: 4px;
}

.heat-cell {
  display: inline-block;
  width: 14px;
  height: 14px;
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

.legend {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 18px;
  color: var(--zy-muted);
  font-size: 12px;
  font-weight: 800;
}

@media (max-width: 980px) {
  .daily-grid,
  .decision-grid {
    grid-template-columns: 1fr;
  }
}
</style>
