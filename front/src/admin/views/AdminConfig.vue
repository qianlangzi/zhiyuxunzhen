<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage } from 'element-plus'
import {
  listSysConfigs,
  saveSysConfig,
  type SysConfigItem,
} from '../api/sysConfig'

/** 配置类型 → 中文说明 */
const TYPE_LABEL: Record<string, string> = {
  MODEL: '大模型',
  SAFETY: '安全策略',
  DAILY_CASE: '每日一题',
  TOKEN_BUDGET: 'Token 预算',
}

const TYPE_OPTIONS = Object.entries(TYPE_LABEL).map(([value, label]) => ({
  value,
  label,
}))

const items = ref<SysConfigItem[]>([])
const loading = ref(false)
const saving = ref(false)

/** 新建配置表单 */
const form = reactive({ configKey: '', configValue: '', configType: '' })

const loadList = async () => {
  loading.value = true
  try {
    items.value = await listSysConfigs()
  } catch {
    // 错误由 http 拦截器提示
  } finally {
    loading.value = false
  }
}

const typeText = (t: string | null) => (t ? TYPE_LABEL[t] ?? t : '-')

const handleSave = async (item: SysConfigItem) => {
  if (!item.configKey || item.configValue == null) return
  saving.value = true
  try {
    await saveSysConfig(
      item.configKey,
      String(item.configValue),
      item.configType || 'MODEL',
    )
    ElMessage.success('已保存')
    await loadList()
  } catch {
    // 错误由 http 拦截器提示
  } finally {
    saving.value = false
  }
}

const handleCreate = async () => {
  if (!form.configKey.trim() || !form.configValue.trim()) {
    ElMessage.warning('请填写配置键和配置值')
    return
  }
  saving.value = true
  try {
    await saveSysConfig(
      form.configKey.trim(),
      form.configValue.trim(),
      form.configType,
    )
    ElMessage.success('创建成功')
    form.configKey = ''
    form.configValue = ''
    await loadList()
  } catch {
    // 错误由 http 拦截器提示
  } finally {
    saving.value = false
  }
}

onMounted(loadList)
</script>

<template>
  <main class="admin-page">
    <section class="admin-page-head">
      <div>
        <span>系统配置</span>
        <h1>平台运行参数管理</h1>
      </div>
      <el-button :loading="loading" plain @click="loadList">刷新</el-button>
    </section>

    <section class="surface-card config-panel">
      <h2 class="admin-section-title">已配置项</h2>
      <el-table v-loading="loading" :data="items" stripe>
        <template #empty>
          <div class="empty-tip">暂无配置，可点击下方「新增配置」添加</div>
        </template>
        <el-table-column prop="configKey" label="配置键" min-width="180" />
        <el-table-column label="类型" width="120">
          <template #default="{ row }">
            <el-tag effect="plain">{{ typeText(row.configType) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="配置值" min-width="200">
          <template #default="{ row }">
            <el-input v-model="row.configValue" />
          </template>
        </el-table-column>
        <el-table-column label="最近更新" width="160">
          <template #default="{ row }">
            {{ row.updatedAt ? row.updatedAt.replace('T', ' ').slice(0, 16) : '-' }}
          </template>
        </el-table-column>
        <el-table-column label="操作" width="120" fixed="right">
          <template #default="{ row }">
            <el-button size="small" type="primary" link :loading="saving" @click="handleSave(row)">
              保存
            </el-button>
          </template>
        </el-table-column>
      </el-table>
    </section>

    <section class="surface-card config-panel">
      <h2 class="admin-section-title">新增配置</h2>
      <el-form :model="form" label-position="top" inline>
        <el-form-item label="配置键">
          <el-input v-model="form.configKey" placeholder="如 ai.primary.model" style="width: 220px" />
        </el-form-item>
        <el-form-item label="配置值">
          <el-input v-model="form.configValue" placeholder="如 deepseek-chat" style="width: 240px" />
        </el-form-item>
        <el-form-item label="类型">
          <el-select v-model="form.configType" style="width: 160px">
            <el-option
              v-for="opt in TYPE_OPTIONS"
              :key="opt.value"
              :label="opt.label"
              :value="opt.value"
            />
          </el-select>
        </el-form-item>
        <el-form-item label=" ">
          <el-button type="primary" :loading="saving" @click="handleCreate">新增</el-button>
        </el-form-item>
      </el-form>
    </section>
  </main>
</template>

<style scoped>
.config-panel {
  padding: 20px;
  margin-bottom: 16px;
}

.empty-tip {
  padding: 24px;
  color: var(--zy-muted);
}
</style>