<script setup lang="ts">
import { ref } from 'vue'
import { marketCases } from '../mockData'

const activeDepartment = ref('全部')
</script>

<template>
  <main class="market-page">
    <section class="page-head">
      <div>
        <span>病例广场</span>
        <h1>复用经过同行验证的教学病例</h1>
      </div>
      <el-button type="primary">提交我的病例</el-button>
    </section>

    <section class="surface-card filter-bar">
      <el-segmented v-model="activeDepartment" :options="['全部', '心血管', '呼吸系统', '消化系统']" />
      <el-input placeholder="搜索病例、疾病系统或作者" clearable>
        <template #prefix>
          <el-icon><Search /></el-icon>
        </template>
      </el-input>
    </section>

    <section class="market-grid">
      <article v-for="item in marketCases" :key="item.title" class="surface-card market-card">
        <div class="card-top">
          <div>
            <strong>{{ item.title }}</strong>
            <span>{{ item.author }} · {{ item.department }} · {{ item.difficulty }}</span>
          </div>
          <el-tag v-if="item.certified" type="success" effect="plain">官方认证</el-tag>
          <el-tag v-else effect="plain">待更多评价</el-tag>
        </div>

        <div class="metric-row">
          <span>
            <b>{{ item.referenceCount }}</b>
            引用
          </span>
          <span>
            <b>{{ item.rating }}</b>
            同行评分
          </span>
        </div>

        <div class="actions">
          <el-button plain>预览试诊</el-button>
          <el-button type="primary">引用到我的班级</el-button>
        </div>
      </article>
    </section>
  </main>
</template>

<style scoped>
.market-page {
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
.market-card span {
  display: block;
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

.filter-bar {
  display: grid;
  grid-template-columns: auto minmax(260px, 420px);
  gap: 14px;
  align-items: center;
  padding: 16px;
}

.market-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 16px;
}

.market-card {
  display: grid;
  gap: 18px;
  padding: 20px;
}

.card-top {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 14px;
}

.market-card strong {
  display: block;
  color: var(--zy-ink);
  font-size: 18px;
}

.metric-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

.metric-row span {
  padding: 12px;
  border-radius: var(--zy-radius-md);
  background: rgba(15, 118, 110, 0.06);
}

.metric-row b {
  display: block;
  color: var(--zy-ink);
  font-size: 24px;
}

.actions {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

@media (max-width: 1180px) {
  .market-grid,
  .filter-bar {
    grid-template-columns: 1fr;
  }
}
</style>
