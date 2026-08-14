<script setup lang="ts">
import { ref } from 'vue'

const model = ref({
  primary: 'Spark Max',
  backup: 'Spark Lite',
  timeout: 10,
  tokenBudget: 180000,
  sensitiveWords: '真实处方, 制毒, 自伤'
})
</script>

<template>
  <main class="admin-page">
    <section class="admin-page-head">
      <div>
        <span>系统配置</span>
        <h1>模型容灾、每日一题和安全规则</h1>
      </div>
      <el-button type="primary" disabled>保存配置</el-button>
    </section>

    <el-alert
      type="warning"
      :closable="false"
      show-icon
      class="demo-alert"
      title="演示模式"
      description="当前页面尚未对接后端接口，所示配置为示例数据，保存操作已禁用。"
    />

    <section class="config-grid">
      <article class="surface-card config-panel">
        <h2 class="admin-section-title">大模型容灾</h2>
        <el-form :model="model" label-position="top">
          <el-form-item label="主模型">
            <el-select v-model="model.primary">
              <el-option label="Spark Max" value="Spark Max" />
              <el-option label="Spark Pro" value="Spark Pro" />
            </el-select>
          </el-form-item>
          <el-form-item label="备用模型">
            <el-select v-model="model.backup">
              <el-option label="Spark Lite" value="Spark Lite" />
              <el-option label="本地规则降级" value="本地规则降级" />
            </el-select>
          </el-form-item>
          <el-form-item label="超时阈值（秒）">
            <el-input-number v-model="model.timeout" :min="3" :max="30" controls-position="right" />
          </el-form-item>
        </el-form>
      </article>

      <article class="surface-card config-panel">
        <h2 class="admin-section-title">运营与安全</h2>
        <el-form :model="model" label-position="top">
          <el-form-item label="每日 Token 预算">
            <el-input-number v-model="model.tokenBudget" :min="10000" :step="10000" controls-position="right" />
          </el-form-item>
          <el-form-item label="敏感词库">
            <el-input v-model="model.sensitiveWords" type="textarea" :rows="4" />
          </el-form-item>
          <el-form-item label="每日一题排期">
            <el-date-picker type="daterange" start-placeholder="开始日期" end-placeholder="结束日期" />
          </el-form-item>
        </el-form>
      </article>
    </section>
  </main>
</template>

<style scoped>
.demo-alert {
  margin-bottom: 16px;
}

.config-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
}

.config-panel {
  padding: 20px;
}

.config-panel h2 {
  margin-bottom: 16px;
}

@media (max-width: 980px) {
  .config-grid {
    grid-template-columns: 1fr;
  }
}
</style>
