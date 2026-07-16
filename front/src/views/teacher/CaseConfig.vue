<script setup lang="ts">
import { ref } from 'vue'
import { ElMessage } from 'element-plus'

const form = ref({
  chief: '胸痛伴气促',
  age: 67,
  diagnosis: '急性冠脉综合征',
  personality: '隐瞒病史',
  tags: ['胸痛鉴别', '心电图', '心衰']
})

const newTag = ref('')

function addTag() {
  if (!newTag.value.trim()) return
  form.value.tags.push(newTag.value.trim())
  newTag.value = ''
}

function saveCase() {
  ElMessage.success('模拟病人配置已保存')
}
</script>

<template>
  <main class="page-shell">
    <section class="page-head">
      <div>
        <span>模拟病人配置</span>
        <h1>配置病例基础信息和教学变量</h1>
      </div>
      <el-button type="primary" @click="saveCase">保存配置</el-button>
    </section>

    <section class="config-grid">
      <article class="surface-card config-card">
        <el-form :model="form" label-position="top">
          <el-form-item label="主诉">
            <el-input v-model="form.chief" />
          </el-form-item>
          <el-form-item label="年龄">
            <el-input-number v-model="form.age" :min="1" :max="110" controls-position="right" />
          </el-form-item>
          <el-form-item label="初步诊断">
            <el-input v-model="form.diagnosis" />
          </el-form-item>
          <el-form-item label="病人性格变量">
            <el-select v-model="form.personality">
              <el-option label="隐瞒病史" value="隐瞒病史" />
              <el-option label="焦虑追问" value="焦虑追问" />
              <el-option label="表达模糊" value="表达模糊" />
            </el-select>
          </el-form-item>
          <el-form-item label="教学标签">
            <div class="tag-editor">
              <el-tag v-for="tag in form.tags" :key="tag" closable @close="form.tags = form.tags.filter((item) => item !== tag)">
                {{ tag }}
              </el-tag>
              <el-input v-model="newTag" placeholder="添加标签" @keyup.enter="addTag" />
              <el-button plain @click="addTag">添加</el-button>
            </div>
          </el-form-item>
        </el-form>
      </article>

      <aside class="surface-card preview-card">
        <span>学生端预览</span>
        <h2>{{ form.chief }}</h2>
        <p>{{ form.age }} 岁患者，进入模拟问诊后会根据“{{ form.personality }}”变量回答问题。</p>
        <div class="tag-row">
          <el-tag v-for="tag in form.tags" :key="tag" effect="plain">{{ tag }}</el-tag>
        </div>
        <div class="note">
          <strong>教学目标</strong>
          <p>引导学生在问诊中补齐危险信号、必要检查和诊断依据。</p>
        </div>
      </aside>
    </section>
  </main>
</template>

<style scoped>
.config-grid {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 360px;
  gap: 16px;
}

.config-card,
.preview-card {
  padding: 20px;
}

.tag-editor,
.tag-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  width: 100%;
}

.tag-editor .el-input {
  width: 180px;
}

.preview-card span {
  color: var(--zy-muted);
  font-size: 13px;
  font-weight: 800;
}

.preview-card h2 {
  margin: 8px 0 10px;
  color: var(--zy-ink);
  font-size: 26px;
}

.preview-card p {
  color: var(--zy-muted);
  line-height: 1.7;
}

.note {
  margin-top: 18px;
  padding: 14px;
  border-radius: 16px;
  background: var(--zy-bg-soft);
}

.note strong {
  color: var(--zy-ink);
}

@media (max-width: 980px) {
  .config-grid {
    grid-template-columns: 1fr;
  }
}
</style>
