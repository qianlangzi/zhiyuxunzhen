<script setup lang="ts">
import { assignments, formatShieldRules } from '../mockData'
</script>

<template>
  <main class="page-shell">
    <section class="page-head">
      <div>
        <span>作业分发</span>
        <h1>查看班级训练任务和提交进度</h1>
      </div>
      <el-button type="primary">新建作业</el-button>
    </section>

    <section class="assignment-list">
      <article v-for="item in assignments" :key="item.title" class="surface-card assignment-card interactive">
        <div>
          <strong>{{ item.title }}</strong>
          <span>{{ item.className }} · {{ item.due }}</span>
          <div class="tag-row">
            <el-tag effect="plain">{{ item.status }}</el-tag>
            <el-tag v-if="item.requireRecord" type="success" effect="plain">需大病历</el-tag>
            <el-tag type="warning" effect="plain">{{ item.variable }}</el-tag>
          </div>
        </div>
        <div class="progress">
          <el-progress :percentage="Math.round((item.submitted / item.total) * 100)" />
          <small>{{ item.submitted }} / {{ item.total }} 已提交</small>
        </div>
      </article>
    </section>

    <section class="surface-card shield-panel">
      <div class="shield-head">
        <div>
          <span>格式盾牌</span>
          <h2>提交前置校验规则</h2>
        </div>
        <el-button plain>编辑规则</el-button>
      </div>
      <div class="rule-grid">
        <article v-for="rule in formatShieldRules" :key="rule.label" class="rule-card">
          <el-tag :type="rule.state === '通过' ? 'success' : rule.state === '打回' ? 'danger' : 'warning'" effect="plain">
            {{ rule.state }}
          </el-tag>
          <strong>{{ rule.label }}</strong>
          <p>{{ rule.detail }}</p>
        </article>
      </div>
    </section>
  </main>
</template>

<style scoped>
.assignment-list {
  display: grid;
  gap: 14px;
}

.assignment-card {
  display: grid;
  grid-template-columns: minmax(0, 0.8fr) minmax(280px, 1fr);
  gap: 18px;
  align-items: center;
  padding: 18px;
}

.assignment-card strong,
.assignment-card span {
  display: block;
}

.assignment-card span,
.progress small,
.shield-head span {
  color: var(--zy-muted);
  font-size: 13px;
  font-weight: 800;
}

.tag-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 12px;
}

.shield-panel {
  padding: 20px;
}

.shield-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 16px;
}

.shield-head h2 {
  margin: 6px 0 0;
  color: var(--zy-ink);
  font-size: 22px;
}

.rule-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 14px;
}

.rule-card {
  padding: 14px;
  border: 1px solid var(--zy-line);
  border-radius: var(--zy-radius-md);
  background: rgba(15, 76, 92, 0.04);
}

.rule-card strong {
  display: block;
  margin-top: 10px;
  color: var(--zy-ink);
}

.rule-card p {
  margin: 8px 0 0;
  color: var(--zy-muted);
  font-size: 13px;
  line-height: 1.6;
}

@media (max-width: 820px) {
  .assignment-card,
  .rule-grid {
    grid-template-columns: 1fr;
  }

  .shield-head {
    align-items: flex-start;
    flex-direction: column;
  }
}
</style>
