<script setup lang="ts">
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'
import { cases } from '../mockData'

const router = useRouter()
const keyword = ref('')
const activeDepartment = ref('全部')

const departments = ['全部', '呼吸系统', '心血管', '消化系统', '已认证']

const filteredCases = computed(() => {
  return cases.filter((item) => {
    const matchesKeyword =
      !keyword.value ||
      item.title.includes(keyword.value) ||
      item.chief.includes(keyword.value) ||
      item.tags.some((tag) => tag.includes(keyword.value))
    const matchesDepartment =
      activeDepartment.value === '全部' ||
      item.department === activeDepartment.value ||
      (activeDepartment.value === '已认证' && item.certified)
    return matchesKeyword && matchesDepartment
  })
})

function enterTraining(caseId: string) {
  router.push({ path: '/student/chat', query: { caseId } })
}
</script>

<template>
  <main class="page-shell">
    <section class="page-head">
      <div>
        <span>选择病例</span>
        <h1>选择一个模拟病人，开始临床问诊训练</h1>
      </div>
    </section>

    <section class="surface-card filter-bar">
      <el-input v-model="keyword" placeholder="搜索病例、症状或系统" clearable>
        <template #prefix>
          <el-icon><Search /></el-icon>
        </template>
      </el-input>
      <el-segmented v-model="activeDepartment" :options="departments" />
    </section>

    <section class="case-grid">
      <article v-for="item in filteredCases" :key="item.title" class="surface-card case-card interactive">
        <div class="case-top">
          <div>
            <strong>{{ item.title }}</strong>
            <span>{{ item.difficulty }} · {{ item.duration }}</span>
          </div>
          <el-tag v-if="item.certified" type="success" effect="plain">已认证</el-tag>
        </div>
        <p>{{ item.chief }}</p>
        <div class="tag-row">
          <el-tag v-for="tag in item.tags" :key="tag" effect="plain">{{ tag }}</el-tag>
        </div>
        <div class="case-foot">
          <span>{{ item.referenceCount }} 次引用 · 评分 {{ item.rating }}</span>
          <el-button type="primary" @click="enterTraining(item.id)">开始问诊</el-button>
        </div>
      </article>
    </section>
  </main>
</template>

<style scoped>
.filter-bar {
  display: grid;
  grid-template-columns: minmax(240px, 420px) auto;
  gap: 14px;
  align-items: center;
  padding: 16px;
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
  min-height: 282px;
  padding: 20px;
}

.case-top,
.case-foot {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
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
.case-card p,
.case-foot span {
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

.case-foot {
  align-items: center;
  margin-top: auto;
}

.case-foot span {
  font-size: 13px;
  font-weight: 800;
}

@media (max-width: 1180px) {
  .case-grid,
  .filter-bar {
    grid-template-columns: 1fr;
  }
}
</style>
