<script setup lang="ts">
import { ref } from 'vue'

const form = ref({
  chief: '胸痛伴气促',
  age: 67,
  diagnosis: '急性冠脉综合征',
  personality: '隐瞒病史',
  tags: ['胸痛鉴别', '心电图', '心衰']
})
</script>

<template>
  <main class="config-page">
    <section class="page-head">
      <span>模拟病人配置</span>
      <h1>用表单生成训练病例</h1>
    </section>

    <section class="config-grid">
      <article class="surface-card panel">
        <el-form :model="form" label-position="top">
          <el-form-item label="主诉">
            <el-input v-model="form.chief" />
          </el-form-item>
          <div class="form-two">
            <el-form-item label="年龄">
              <el-input-number v-model="form.age" :min="1" :max="110" controls-position="right" />
            </el-form-item>
            <el-form-item label="病人性格">
              <el-select v-model="form.personality">
                <el-option label="配合" value="配合" />
                <el-option label="暴躁" value="暴躁" />
                <el-option label="隐瞒病史" value="隐瞒病史" />
              </el-select>
            </el-form-item>
          </div>
          <el-form-item label="真实诊断">
            <el-input v-model="form.diagnosis" />
          </el-form-item>
          <el-form-item label="知识点标签">
            <el-select v-model="form.tags" multiple :multiple-limit="5">
              <el-option label="胸痛鉴别" value="胸痛鉴别" />
              <el-option label="心电图" value="心电图" />
              <el-option label="心衰" value="心衰" />
              <el-option label="肺水肿" value="肺水肿" />
              <el-option label="血常规判读" value="血常规判读" />
            </el-select>
          </el-form-item>
          <el-button type="primary">保存病例</el-button>
        </el-form>
      </article>

      <aside class="surface-card preview">
        <span>预览</span>
        <h2>{{ form.age }} 岁患者，{{ form.chief }}</h2>
        <p>真实诊断：{{ form.diagnosis }}。性格特征：{{ form.personality }}。</p>
        <div class="tag-row">
          <el-tag v-for="tag in form.tags" :key="tag">{{ tag }}</el-tag>
        </div>
      </aside>
    </section>
  </main>
</template>

<style scoped>
.config-page {
  display: grid;
  gap: 20px;
}

.page-head span,
.preview span {
  color: var(--zy-muted);
  font-size: 13px;
  font-weight: 800;
}

.page-head h1 {
  margin: 6px 0 0;
  color: var(--zy-ink);
  font-size: clamp(26px, 3vw, 34px);
}

.config-grid {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 360px;
  gap: 16px;
}

.panel,
.preview {
  padding: 20px;
}

.form-two {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 14px;
}

.preview h2 {
  margin: 10px 0;
  color: var(--zy-ink);
}

.preview p {
  color: var(--zy-muted);
  line-height: 1.7;
}

.tag-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

@media (max-width: 980px) {
  .config-grid,
  .form-two {
    grid-template-columns: 1fr;
  }
}
</style>
