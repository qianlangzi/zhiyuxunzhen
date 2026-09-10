<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { ElMessage } from 'element-plus'
import {
  listSysConfigs,
  saveSysConfig,
  type SysConfigItem,
} from '../api/sysConfig'
import {
  getSmsConfig,
  switchSmsProvider,
  testSmsSend,
  SMS_PROVIDER_LABEL,
  type SmsConfigVO,
} from '../api/smsConfig'
import { fmtDateTime } from '../utils/format'

/** 配置类型 → 中文说明 */
const TYPE_LABEL: Record<string, string> = {
  MODEL: '大模型',
  SAFETY: '安全策略',
  DAILY_CASE: '每日一题',
  TOKEN_BUDGET: 'Token 预算',
  SMS: '短信服务',
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

// ==================== 短信服务商（热切换） ====================

const sms = ref<SmsConfigVO | null>(null)
const smsLoading = ref(false)
const smsSaving = ref(false)
const smsTesting = ref(false)
/** 下拉选中值（保存前不生效） */
const smsSelected = ref('')
const testPhone = ref('')

const loadSms = async () => {
  smsLoading.value = true
  try {
    sms.value = await getSmsConfig()
    smsSelected.value = sms.value.provider || ''
  } catch {
    // 错误由 http 拦截器提示
  } finally {
    smsLoading.value = false
  }
}

const providerLabel = (p: string) => SMS_PROVIDER_LABEL[p] ?? (p || '未配置')

const handleSwitchSms = async () => {
  if (!smsSelected.value) {
    ElMessage.warning('请选择短信服务商')
    return
  }
  smsSaving.value = true
  try {
    await switchSmsProvider(smsSelected.value)
    ElMessage.success('已切换，立即生效（无需重启服务）')
    await loadSms()
  } catch {
    // 错误由 http 拦截器提示
  } finally {
    smsSaving.value = false
  }
}

const handleTestSms = async () => {
  if (!/^1[3-9]\d{9}$/.test(testPhone.value.trim())) {
    ElMessage.warning('请填写正确的手机号')
    return
  }
  smsTesting.value = true
  try {
    const res = await testSmsSend(testPhone.value.trim())
    if (res.success) {
      ElMessage.success(res.message || '测试短信已提交发送')
    } else {
      ElMessage.error(res.message || '测试发送失败')
    }
  } catch (e) {
    ElMessage.error(e instanceof Error ? e.message : '测试发送失败')
  } finally {
    smsTesting.value = false
  }
}

onMounted(() => {
  loadList()
  loadSms()
})
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

    <section v-loading="smsLoading" class="surface-card config-panel">
      <h2 class="admin-section-title">短信服务商</h2>
      <p class="sms-hint">
        注册/登录验证码的发送通道。切换后立即生效，无需重启后端服务；密钥仍由服务器环境变量注入，不在此处填写。
      </p>
      <div class="sms-row">
        <span class="sms-label">当前生效</span>
        <el-tag :type="sms?.provider ? 'success' : 'info'" effect="plain">
          {{ providerLabel(sms?.provider ?? '') }}
        </el-tag>
        <span class="sms-sub">
          来源：{{ sms?.source === 'DB' ? '管理端配置' : sms?.source === 'ENV' ? '环境变量' : '未配置' }}
          <template v-if="sms?.envProvider">（环境变量默认值：{{ providerLabel(sms.envProvider) }}）</template>
        </span>
      </div>
      <div class="sms-row">
        <span class="sms-label">通道就绪</span>
        <el-tag :type="sms?.aliyunReady ? 'success' : 'danger'" effect="plain">
          阿里云短信认证 {{ sms?.aliyunReady ? '已配置' : '未配置' }}
        </el-tag>
        <el-tag :type="sms?.juheReady ? 'success' : 'danger'" effect="plain">
          聚合数据 {{ sms?.juheReady ? '已配置' : '未配置' }}
        </el-tag>
        <span class="sms-sub">
          签名 {{ sms?.aliyunSignName || '-' }} · 模板 {{ sms?.aliyunTemplateCode || '-' }}
        </span>
      </div>
      <div class="sms-row">
        <span class="sms-label">切换通道</span>
        <el-select v-model="smsSelected" style="width: 220px" placeholder="选择短信服务商">
          <el-option
            v-for="p in sms?.supported ?? []"
            :key="p"
            :label="providerLabel(p)"
            :value="p"
          />
        </el-select>
        <el-button type="primary" :loading="smsSaving" @click="handleSwitchSms">
          保存并生效
        </el-button>
      </div>
      <div class="sms-row">
        <span class="sms-label">测试发送</span>
        <el-input
          v-model="testPhone"
          placeholder="输入手机号"
          maxlength="11"
          style="width: 220px"
        />
        <el-button :loading="smsTesting" @click="handleTestSms">发一条测试短信</el-button>
        <span class="sms-sub">真实下发并计费，建议先用本人手机号验证通道</span>
      </div>
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
            {{ fmtDateTime(row.updatedAt) }}
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

.sms-hint {
  margin: 0 0 14px;
  font-size: 13px;
  line-height: 1.6;
  color: var(--zy-muted);
}

.sms-row {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
  margin-bottom: 12px;
}

.sms-label {
  width: 72px;
  font-size: 13px;
  color: var(--zy-muted);
}

.sms-sub {
  font-size: 12px;
  color: var(--zy-muted);
}
</style>