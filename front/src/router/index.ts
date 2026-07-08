import { createRouter, createWebHistory } from 'vue-router'

const STUDENT_ROLE = 0
const TEACHER_ROLE = 1
const ADMIN_ROLE = 4

function readRole() {
  const role = localStorage.getItem('zhiyu_role')
  if (role !== String(STUDENT_ROLE) && role !== String(TEACHER_ROLE) && role !== String(ADMIN_ROLE)) return null
  return Number(role)
}

function clearLogin() {
  localStorage.removeItem('zhiyu_token')
  localStorage.removeItem('zhiyu_username')
  localStorage.removeItem('zhiyu_role')
}

// 路由守卫:未登录跳 /login
const router = createRouter({
  history: createWebHistory(),
  scrollBehavior() {
    return { top: 0 }
  },
  routes: [
    { path: '/', component: () => import('@/views/Home.vue') },
    { path: '/login', component: () => import('@/views/Login.vue') },
    { path: '/student/cases', component: () => import('@/views/student/Cases.vue'), meta: { role: STUDENT_ROLE } },
    { path: '/student/chat', component: () => import('@/views/student/ChatRoom.vue'), meta: { role: STUDENT_ROLE } },
    { path: '/student/image', component: () => import('@/views/student/ImageReview.vue'), meta: { role: STUDENT_ROLE } },
    { path: '/student/feedback', component: () => import('@/views/student/Feedback.vue'), meta: { role: STUDENT_ROLE } },
    { path: '/student/record', component: () => import('@/views/student/RecordSubmit.vue'), meta: { role: STUDENT_ROLE } },
    { path: '/student/daily', component: () => import('@/views/student/DailyCase.vue'), meta: { role: STUDENT_ROLE } },
    { path: '/student/mistakes', component: () => import('@/views/student/Mistakes.vue'), meta: { role: STUDENT_ROLE } },
    { path: '/teacher/cases', component: () => import('@/views/teacher/CaseConfig.vue'), meta: { role: TEACHER_ROLE } },
    { path: '/teacher/market', component: () => import('@/views/teacher/CaseMarket.vue'), meta: { role: TEACHER_ROLE } },
    { path: '/teacher/assignments', component: () => import('@/views/teacher/Assignments.vue'), meta: { role: TEACHER_ROLE } },
    { path: '/teacher/review', component: () => import('@/views/teacher/Review.vue'), meta: { role: TEACHER_ROLE } },
    { path: '/teacher/insights', component: () => import('@/views/teacher/Insights.vue'), meta: { role: TEACHER_ROLE } },
    { path: '/profile', component: () => import('@/views/Profile.vue') },
    { path: '/:pathMatch(.*)*', redirect: '/' }
  ]
})

router.beforeEach((to, _from, next) => {
  const token = localStorage.getItem('zhiyu_token')
  const role = readRole()

  if (to.path === '/login' && token && role !== null) {
    next('/')
  } else if (to.path !== '/login' && (!token || role === null)) {
    clearLogin()
    next('/login')
  } else if (typeof to.meta.role === 'number' && to.meta.role !== role) {
    next('/')
  } else {
    next()
  }
})

export default router
