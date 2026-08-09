<script setup lang="ts">
import { ref, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage, type FormInstance, type FormRules } from 'element-plus'
import { useAuthStore } from '../stores/auth'
import { ADMIN_ROLES } from '../types'
import brandLogo from '@/assets/brand-logo.png'

const router = useRouter()
const authStore = useAuthStore()

const formRef = ref<FormInstance>()
const loading = ref(false)

const form = reactive({
  username: '',
  password: '',
})

const rules: FormRules = {
  username: [{ required: true, message: '请输入用户名', trigger: 'blur' }],
  password: [{ required: true, message: '请输入密码', trigger: 'blur' }],
}

async function handleLogin(): Promise<void> {
  if (!formRef.value) return
  const valid = await formRef.value.validate().catch(() => false)
  if (!valid) return

  loading.value = true
  try {
    const defaultPath = await authStore.login({
      username: form.username.trim(),
      password: form.password,
    })

    // 校验角色是否允许登录管理端
    if (authStore.role !== null && !ADMIN_ROLES.includes(authStore.role)) {
      ElMessage.error('当前账号无管理端访问权限')
      await authStore.logout()
      return
    }

    ElMessage.success('登录成功')
    router.replace(defaultPath)
  } catch (e) {
    // 所有业务错误的 ElMessage 提示已由 http.ts 响应拦截器统一处理，此处不重复弹窗：
    //   - 2001 用户名或密码错误：http.ts 已弹提示
    //   - 2002 账号冻结：http.ts 已清登录态并跳转登录页
    //   - 1001/1002：http.ts 已处理 token 失效
    //   - 1003/其他业务错误：http.ts 已弹提示
    //   - 网络错误等：http.ts 已弹提示
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="login-frame">
    <div class="login-card surface-card">
      <div class="login-brand">
        <img :src="brandLogo" alt="" />
        <div>
          <strong>知语寻真</strong>
          <span>管理控制台</span>
        </div>
      </div>

      <el-form
        ref="formRef"
        :model="form"
        :rules="rules"
        label-position="top"
        @submit.prevent="handleLogin"
      >
        <el-form-item label="用户名" prop="username">
          <el-input
            v-model="form.username"
            placeholder="请输入用户名"
            clearable
            @keyup.enter="handleLogin"
          />
        </el-form-item>

        <el-form-item label="密码" prop="password">
          <el-input
            v-model="form.password"
            type="password"
            placeholder="请输入密码"
            show-password
            @keyup.enter="handleLogin"
          />
        </el-form-item>

        <el-button
          type="primary"
          :loading="loading"
          class="login-submit"
          @click="handleLogin"
        >
          登 录
        </el-button>
      </el-form>

      <p class="login-hint">
        管理端仅限教学秘书、教研室主任、管理员、运维登录。
      </p>
    </div>
  </div>
</template>

<style scoped>
.login-frame {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100dvh;
  background: var(--zy-bg);
  padding: 20px;
}

.login-card {
  width: 100%;
  max-width: 380px;
  padding: 36px 28px 28px;
}

.login-brand {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 28px;
}

.login-brand img {
  width: 42px;
  height: 42px;
  border: 1px solid var(--zy-line);
  border-radius: 12px;
  object-fit: contain;
}

.login-brand strong {
  display: block;
  color: var(--zy-ink);
  font-size: 18px;
}

.login-brand span {
  display: block;
  color: var(--zy-muted);
  font-size: 12px;
  font-weight: 800;
}

.login-submit {
  width: 100%;
  margin-top: 8px;
}

.login-hint {
  margin: 20px 0 0;
  color: var(--zy-muted);
  font-size: 12px;
  font-weight: 800;
  text-align: center;
  line-height: 1.6;
}
</style>
