import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from './stores/auth'
import { ADMIN_ROLES, getDefaultPath } from './types'

const adminRouter = createRouter({
  history: createWebHistory('/'),
  scrollBehavior() {
    return { top: 0 }
  },
  routes: [
    {
      path: '/login',
      name: 'login',
      component: () => import('./views/Login.vue'),
      meta: { public: true },
    },
    {
      path: '/',
      component: () => import('./views/AdminDashboard.vue'),
      meta: { roles: [3, 4, 5] },
    },
    {
      path: '/users',
      component: () => import('./views/UserManage.vue'),
      meta: { roles: [2, 4] },
    },
    {
      path: '/audits',
      component: () => import('./views/audit/AuditCenterLayout.vue'),
      redirect: '/audits/teacher',
      meta: { roles: [4, 6] },
      children: [
        {
          path: 'teacher',
          component: () => import('./views/audit/AuditTeacher.vue'),
          meta: { roles: [4, 6] },
        },
        {
          path: 'case',
          component: () => import('./views/audit/AuditCase.vue'),
          meta: { roles: [4, 6] },
        },
        {
          path: 'question',
          component: () => import('./views/QuestionAudits.vue'),
          meta: { roles: [4, 6] },
        },
        {
          path: 'textbook',
          component: () => import('./views/TextbookManage.vue'),
          meta: { roles: [4, 6] },
        },
      ],
    },
    // 旧独立入口兼容：跳转到审核中心对应二级标签
    {
      path: '/question-audits',
      redirect: '/audits/question',
    },
    {
      path: '/textbook-manage',
      redirect: '/audits/textbook',
    },
    {
      path: '/ai-config',
      component: () => import('./views/ai/AiConfigLayout.vue'),
      redirect: '/ai-config/model',
      meta: { roles: [4] },
      children: [
        {
          path: 'status',
          component: () => import('./views/ai/AiStatus.vue'),
          meta: { roles: [4] },
        },
        {
          path: 'model',
          component: () => import('./views/ModelManage.vue'),
          meta: { roles: [4] },
        },
        {
          path: 'token',
          component: () => import('./views/ai/TokenManage.vue'),
          meta: { roles: [4] },
        },
        {
          path: 'prompt',
          component: () => import('./views/ai/AiPromptManage.vue'),
          meta: { roles: [4] },
        },
        {
          path: 'agent',
          component: () => import('./views/ai/AiAgentManage.vue'),
          meta: { roles: [4] },
        },
        {
          path: 'rag',
          component: () => import('./views/ai/AiRuntimeManage.vue'),
          meta: { roles: [4] },
        },
      ],
    },
    // 旧独立入口兼容：统一跳转到 AI 配置中心的模型子页
    {
      path: '/models',
      redirect: '/ai-config/model',
    },
    {
      path: '/config',
      component: () => import('./views/AdminConfig.vue'),
      meta: { roles: [4] },
    },
    {
      path: '/logs',
      component: () => import('./views/AdminLogs.vue'),
      meta: { roles: [4] },
    },
    {
      path: '/no-access',
      name: 'no-access',
      component: () => import('./views/NoAccess.vue'),
      meta: { roles: [2] },
    },
    { path: '/:pathMatch(.*)*', redirect: '/' },
  ],
})

// ---------- 路由守卫 ----------
adminRouter.beforeEach(async (to) => {
  // 公开路由（登录页）直接放行
  if (to.meta.public) {
    // 已登录用户访问登录页时跳转到默认页
    const authStore = useAuthStore()
    if (authStore.isAuthenticated) {
      return getDefaultPath(authStore.role ?? -1)
    }
    return true
  }

  const authStore = useAuthStore()

  // 无 token → 登录页
  if (!authStore.isAuthenticated) {
    // 尝试恢复会话（token 存在但 user 未加载时）
    const restored = await authStore.restore()
    if (!restored) {
      return { name: 'login' }
    }
  }

  // 校验角色是否允许登录管理端
  if (authStore.role !== null && !ADMIN_ROLES.includes(authStore.role)) {
    authStore.resetState()
    return { name: 'login' }
  }

  // 校验目标路由的角色权限
  const allowedRoles = to.meta.roles as number[] | undefined
  if (allowedRoles && authStore.role !== null && !allowedRoles.includes(authStore.role)) {
    // 角色无权访问目标路由 → 跳转到默认落地页
    return getDefaultPath(authStore.role)
  }

  return true
})

export default adminRouter
