import { createApp } from 'vue'
import { createPinia } from 'pinia'
import ElementPlus from 'element-plus'
import 'element-plus/dist/index.css'
import * as ElementPlusIconsVue from '@element-plus/icons-vue'
import AdminApp from './AdminApp.vue'
import adminRouter from './router'
import { useAuthStore } from './stores/auth'
import { getDefaultPath, type LoginResponse } from './types'
import '@/styles/main.css'
import './styles.css'

const app = createApp(AdminApp)
const pinia = createPinia()

// Pinia 必须先于 router 安装：路由守卫 beforeEach 中调用 useAuthStore() 需要活跃的 Pinia 实例
app.use(pinia)

// 注册 token 刷新事件监听：http.ts 刷新成功后派发 CustomEvent，store 据此更新角色并重算菜单
const authStore = useAuthStore()
window.addEventListener('admin-token-refreshed', (event) => {
  const resp = (event as CustomEvent<LoginResponse>).detail
  const previousRole = authStore.role
  authStore.handleTokenRefreshed(resp)
  // 角色变更后（如降级），若当前路由新角色无权访问则立即跳转到默认落地页
  // 避免用户停留在已无权限的页面上（路由守卫不会因 role 变化而自动触发）
  if (previousRole !== null && previousRole !== resp.role) {
    const current = adminRouter.currentRoute.value
    const allowedRoles = current.meta.roles as number[] | undefined
    if (allowedRoles && !allowedRoles.includes(resp.role)) {
      adminRouter.replace(getDefaultPath(resp.role))
    }
  }
})

// 注册 Element Plus 图标
for (const [key, component] of Object.entries(ElementPlusIconsVue)) {
  app.component(key, component as any)
}

// 安装路由（守卫在 app.mount 触发首次导航时才执行，此时 Pinia 已就绪）
app.use(adminRouter)
app.use(ElementPlus)
app.mount('#admin-app')
