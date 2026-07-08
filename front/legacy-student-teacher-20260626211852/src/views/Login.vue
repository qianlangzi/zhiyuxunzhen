<script setup lang="ts">
import { computed, ref } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import http from '@/api'
import { useUserStore } from '@/stores/user'
import brandLogo from '@/assets/brand-logo.png'

type LoginRole = 'teacher' | 'student'

const router = useRouter()
const user = useUserStore()

const allowDemoLogin = import.meta.env.DEV
const selectedRole = ref<LoginRole>('teacher')
const form = ref({
  username: allowDemoLogin ? 'teacher01' : '',
  password: allowDemoLogin ? '123456' : ''
})
const loading = ref(false)

const roleMeta = computed(() => {
  if (selectedRole.value === 'teacher') {
    return {
      label: '教师端',
      username: 'teacher01',
      role: 1,
      title: '教师工作区',
      note: '配置模拟病人，分发作业，查看批阅与班级薄弱点。'
    }
  }
  return {
    label: '学生端',
    username: 'student01',
    role: 0,
    title: '学生训练区',
    note: '选择病例，完成问诊、影像判读和大病历提交。'
  }
})

function selectRole(role: LoginRole) {
  selectedRole.value = role
  form.value.username = allowDemoLogin ? (role === 'teacher' ? 'teacher01' : 'student01') : ''
  form.value.password = allowDemoLogin ? '123456' : ''
}

async function submit() {
  loading.value = true
  try {
    const r: any = await http.post('/v1/user/login', form.value)
    user.setLogin(r.data.token, r.data.username, r.data.role)
    ElMessage.success('登录成功')
    router.push('/')
  } catch (error) {
    if (!allowDemoLogin) return

    const isKnownDemoUser =
      form.value.password === '123456' &&
      ((form.value.username === 'teacher01' && selectedRole.value === 'teacher') ||
        (form.value.username === 'student01' && selectedRole.value === 'student'))

    if (!isKnownDemoUser) return

    user.setLogin(
      `demo-${selectedRole.value}-token`,
      form.value.username,
      roleMeta.value.role
    )
    ElMessage.warning('登录服务暂不可用，已进入开发预览')
    router.push('/')
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <main class="login-page">
    <section class="login-hero zy-page">
      <div class="login-story">
        <div class="brand-chip">
          <span><img :src="brandLogo" alt="" /></span>
          智愈寻真
        </div>

        <h1>内科学训练</h1>
        <p class="hero-copy">
          选择身份后进入对应页面。
        </p>
      </div>

      <aside class="login-card glass-panel" aria-label="登录面板">
        <div class="login-card-head">
          <span class="zy-kicker">选择身份</span>
          <h2>{{ roleMeta.title }}</h2>
          <p>{{ roleMeta.note }}</p>
        </div>

        <div class="role-switch" aria-label="角色切换" role="group">
          <button
            class="zy-button"
            :class="{ active: selectedRole === 'teacher' }"
            :aria-pressed="selectedRole === 'teacher'"
            type="button"
            @click="selectRole('teacher')"
          >
            <el-icon><Management /></el-icon>
            教师端
          </button>
          <button
            class="zy-button"
            :class="{ active: selectedRole === 'student' }"
            :aria-pressed="selectedRole === 'student'"
            type="button"
            @click="selectRole('student')"
          >
            <el-icon><Reading /></el-icon>
            学生端
          </button>
        </div>

        <el-form class="login-form" :model="form" label-position="top" @submit.prevent="submit">
          <el-form-item label="用户名">
            <el-input v-model="form.username" autocomplete="username" size="large" />
          </el-form-item>
          <el-form-item label="密码">
            <el-input
              v-model="form.password"
              autocomplete="current-password"
              show-password
              size="large"
              type="password"
            />
          </el-form-item>
          <el-button class="submit-button" type="primary" size="large" native-type="submit" :loading="loading">
            登录 {{ roleMeta.label }}
          </el-button>
        </el-form>

      </aside>
    </section>
  </main>
</template>

<style scoped>
.login-page {
  min-height: 100dvh;
  padding: 36px 0;
  overflow: hidden;
}

.login-hero {
  display: grid;
  grid-template-columns: minmax(0, 1.08fr) minmax(420px, 0.92fr);
  gap: 44px;
  align-items: center;
  min-height: calc(100dvh - 72px);
}

.login-story {
  position: relative;
  padding: 28px 0;
}

.brand-chip {
  position: relative;
  z-index: 1;
  display: inline-flex;
  align-items: center;
  gap: 10px;
  padding: 8px 14px 8px 8px;
  border: 1px solid var(--zy-line);
  border-radius: 999px;
  background: #fff;
  color: var(--zy-brand-strong);
  font-weight: 900;
}

.brand-chip span {
  display: grid;
  overflow: hidden;
  place-items: center;
  width: 32px;
  height: 32px;
  border: 1px solid var(--zy-line);
  border-radius: 10px;
  background: #fff;
}

.brand-chip img {
  width: 100%;
  height: 100%;
  object-fit: contain;
}

h1 {
  position: relative;
  z-index: 1;
  max-width: 850px;
  margin: 28px 0 20px;
  color: var(--zy-ink);
  font-size: clamp(46px, 6.2vw, 88px);
  line-height: 0.98;
  letter-spacing: 0;
}

.hero-copy {
  position: relative;
  z-index: 1;
  max-width: 620px;
  margin: 0;
  color: var(--zy-muted);
  font-size: 19px;
  line-height: 1.8;
}

.login-card {
  position: relative;
  padding: 30px;
  border-radius: var(--zy-radius-xl);
}

.login-card::after {
  display: none;
}

.login-card-head h2 {
  margin: 14px 0 10px;
  color: var(--zy-ink);
  font-size: 30px;
  line-height: 1.16;
}

.login-card-head p {
  margin: 0;
  color: var(--zy-muted);
  font-size: 15px;
  line-height: 1.7;
}

.role-switch {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
  margin: 24px 0;
  padding: 6px;
  border: 1px solid var(--zy-line);
  border-radius: 999px;
  background: rgba(15, 118, 110, 0.06);
}

.role-switch button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  min-height: 44px;
  color: var(--zy-muted);
  background: transparent;
  font-weight: 900;
}

.role-switch button.active {
  color: #fff;
  background: var(--zy-brand);
  box-shadow: 0 14px 28px rgba(15, 118, 110, 0.2);
}

.login-form {
  position: relative;
  z-index: 1;
}

.submit-button {
  width: 100%;
  min-height: 48px;
  margin-top: 6px;
  font-size: 16px;
}

@media (max-width: 1100px) {
  .login-hero {
    grid-template-columns: 1fr;
    align-items: start;
  }

  .login-card {
    max-width: 620px;
  }
}

@media (max-width: 680px) {
  .login-page {
    padding: 18px 0 28px;
  }

  h1 {
    font-size: clamp(40px, 12vw, 58px);
  }

  .login-card {
    min-width: 0;
    padding: 22px;
  }
}
</style>
