import { createRouter, createWebHistory } from 'vue-router'

const adminRouter = createRouter({
  history: createWebHistory('/'),
  scrollBehavior() {
    return { top: 0 }
  },
  routes: [
    { path: '/', component: () => import('./views/AdminDashboard.vue') },
    { path: '/audits', component: () => import('./views/AdminAudits.vue') },
    { path: '/config', component: () => import('./views/AdminConfig.vue') },
    { path: '/logs', component: () => import('./views/AdminLogs.vue') },
    { path: '/:pathMatch(.*)*', redirect: '/' }
  ]
})

export default adminRouter
