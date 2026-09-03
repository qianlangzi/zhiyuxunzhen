<script setup lang="ts">
/**
 * 强制修改密码对话框
 *
 * 触发条件：登录响应 /auth/me 返回 mustChangePassword=true
 * （批量导入学生首次登录时后端置 true，改密成功后置 false）
 *
 * 安全策略：
 *   - 模态不可关闭（禁用遮罩点击、ESC、关闭按钮），必须完成改密
 *   - 前端预校验与后端 ChangePasswordRequest 规则对齐：
 *     8-32 字符、必须同时包含字母和数字、新密码 ≠ 原密码、两次输入一致
 */
import { reactive, ref } from 'vue'
import type { FormInstance, FormRules } from 'element-plus'
import { ElMessage } from 'element-plus'
import { useAuthStore } from '../stores/auth'

const authStore = useAuthStore()

const formRef = ref<FormInstance>()
const submitting = ref(false)
const form = reactive({
  oldPassword: '',
  newPassword: '',
  confirmPassword: '',
})

const rules: FormRules = {
  oldPassword: [{ required: true, message: '请输入原密码', trigger: 'blur' }],
  newPassword: [
    { required: true, message: '请输入新密码', trigger: 'blur' },
    { min: 8, max: 32, message: '密码长度需在 8-32 字符之间', trigger: 'blur' },
    {
      validator: (_rule, value: string, callback) => {
        if (!value) return callback()
        if (!/(?=.*[A-Za-z])(?=.*\d)/.test(value)) {
          return callback(new Error('密码必须同时包含字母和数字'))
        }
        if (value === form.oldPassword) {
          return callback(new Error('新密码不能与原密码相同'))
        }
        callback()
      },
      trigger: 'blur',
    },
  ],
  confirmPassword: [
    { required: true, message: '请再次输入新密码', trigger: 'blur' },
    {
      validator: (_rule, value: string, callback) => {
        if (!value) return callback()
        if (value !== form.newPassword) {
          return callback(new Error('两次输入的密码不一致'))
        }
        callback()
      },
      trigger: 'blur',
    },
  ],
}

async function submit(): Promise<void> {
  if (!formRef.value) return
  try {
    await formRef.value.validate()
  } catch {
    return // 校验未通过
  }

  submitting.value = true
  try {
    await authStore.changePassword(form.oldPassword, form.newPassword)
    ElMessage.success('密码修改成功')
    // store 中 mustChangePassword 已置 false，对话框自动关闭
    resetForm()
  } catch {
    // 错误提示由 http.ts 拦截器统一处理
  } finally {
    submitting.value = false
  }
}

function resetForm(): void {
  form.oldPassword = ''
  form.newPassword = ''
  form.confirmPassword = ''
  formRef.value?.clearValidate()
}
</script>

<template>
  <el-dialog
    :model-value="authStore.mustChangePassword"
    title="首次登录请修改密码"
    width="440px"
    :close-on-click-modal="false"
    :close-on-press-escape="false"
    :show-close="false"
    align-center
  >
    <el-alert
      type="warning"
      :closable="false"
      title="您的账号使用临时密码登录，为保障安全请先修改密码。"
      show-icon
      style="margin-bottom: 18px"
    />

    <el-form ref="formRef" :model="form" :rules="rules" label-position="top">
      <el-form-item label="原密码" prop="oldPassword">
        <el-input
          v-model="form.oldPassword"
          type="password"
          show-password
          autocomplete="current-password"
          placeholder="请输入当前临时密码"
        />
      </el-form-item>
      <el-form-item label="新密码" prop="newPassword">
        <el-input
          v-model="form.newPassword"
          type="password"
          show-password
          autocomplete="new-password"
          placeholder="8-32 位，需同时包含字母和数字"
        />
      </el-form-item>
      <el-form-item label="确认新密码" prop="confirmPassword">
        <el-input
          v-model="form.confirmPassword"
          type="password"
          show-password
          autocomplete="new-password"
          placeholder="请再次输入新密码"
          @keyup.enter="submit"
        />
      </el-form-item>
    </el-form>

    <template #footer>
      <el-button type="primary" :loading="submitting" @click="submit">
        确认修改
      </el-button>
    </template>
  </el-dialog>
</template>
