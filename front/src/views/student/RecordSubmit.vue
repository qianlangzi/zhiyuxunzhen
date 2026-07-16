<script setup lang="ts">
import { ref } from 'vue'
import { ElMessage } from 'element-plus'
import { formatShieldRules } from '../mockData'

const form = ref({
  chief: '',
  history: '',
  past: '',
  exam: '',
  diagnosis: '',
  plan: ''
})

function saveDraft() {
  ElMessage.success('草稿已保存')
}

function submitRecord() {
  if (!form.value.chief.trim() || !form.value.history.trim()) {
    ElMessage.warning('请至少填写主诉和现病史')
    return
  }
  ElMessage.success('病历已提交批阅')
}
</script>

<template>
  <main class="page-shell">
    <section class="page-head">
      <div>
        <span>大病历提交</span>
        <h1>整理问诊后的结构化病历</h1>
      </div>
    </section>

    <section class="record-grid">
      <article class="surface-card record-card">
        <el-form label-position="top">
          <el-form-item label="主诉">
            <el-input v-model="form.chief" placeholder="例如：活动后胸闷 3 个月，加重 1 周" />
          </el-form-item>
          <el-form-item label="现病史">
            <el-input v-model="form.history" type="textarea" :rows="5" placeholder="按时间线描述症状出现、演变和就诊经过" />
          </el-form-item>
          <el-form-item label="既往史">
            <el-input v-model="form.past" type="textarea" :rows="3" placeholder="记录慢病、手术、过敏和用药史" />
          </el-form-item>
          <el-form-item label="体格检查">
            <el-input v-model="form.exam" type="textarea" :rows="3" placeholder="记录阳性体征和关键阴性体征" />
          </el-form-item>
          <el-form-item label="初步诊断">
            <el-input v-model="form.diagnosis" placeholder="填写诊断倾向和鉴别诊断" />
          </el-form-item>
          <el-form-item label="诊疗计划">
            <el-input v-model="form.plan" type="textarea" :rows="3" placeholder="填写下一步检查、治疗和观察计划" />
          </el-form-item>
          <div class="actions">
            <span>文本上限 5000 字</span>
            <div>
              <el-button plain @click="saveDraft">保存草稿</el-button>
              <el-button type="primary" @click="submitRecord">提交批阅</el-button>
            </div>
          </div>
        </el-form>
      </article>

      <aside class="surface-card shield-panel">
        <h2>格式盾牌</h2>
        <p>提交前系统会检查关键字段，减少因格式问题被退回。</p>
        <article v-for="rule in formatShieldRules" :key="rule.label" class="rule-row">
          <el-tag :type="rule.state === '通过' ? 'success' : rule.state === '打回' ? 'danger' : 'warning'" effect="plain">
            {{ rule.state }}
          </el-tag>
          <strong>{{ rule.label }}</strong>
          <span>{{ rule.detail }}</span>
        </article>
      </aside>
    </section>
  </main>
</template>

<style scoped>
.record-grid {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 340px;
  gap: 16px;
}

.record-card,
.shield-panel {
  padding: 20px;
}

.actions {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.actions span,
.shield-panel p,
.rule-row span {
  color: var(--zy-muted);
  font-size: 13px;
  font-weight: 800;
  line-height: 1.6;
}

.shield-panel h2 {
  margin: 0 0 8px;
  color: var(--zy-ink);
  font-size: 22px;
}

.rule-row {
  display: grid;
  gap: 8px;
  padding: 14px 0;
  border-top: 1px solid var(--zy-line);
}

.rule-row strong {
  color: var(--zy-ink);
}

@media (max-width: 980px) {
  .record-grid {
    grid-template-columns: 1fr;
  }

  .actions {
    align-items: flex-start;
    flex-direction: column;
  }
}
</style>
