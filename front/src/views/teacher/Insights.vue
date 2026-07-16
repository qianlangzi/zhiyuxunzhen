<script setup lang="ts">
import { ElMessage } from 'element-plus'
import { weakness } from '../mockData'

function createPractice(tag: string) {
  ElMessage.success(`已为「${tag}」生成专项练习草稿`)
}
</script>

<template>
  <main class="page-shell">
    <section class="page-head">
      <div>
        <span>班级常错点</span>
        <h1>查看班级薄弱点并安排针对性练习</h1>
      </div>
    </section>

    <section class="weakness-grid">
      <article v-for="item in weakness" :key="item.tag" class="surface-card weakness-card interactive">
        <div>
          <strong>{{ item.tag }}</strong>
          <span>{{ item.count }} 次相关训练</span>
        </div>
        <el-progress :percentage="Math.round(item.avg * 100)" />
        <p>平均掌握度 {{ Math.round(item.avg * 100) }}%，建议安排补救病例。</p>
        <el-button plain @click="createPractice(item.tag)">创建专项练习</el-button>
      </article>
    </section>
  </main>
</template>

<style scoped>
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
