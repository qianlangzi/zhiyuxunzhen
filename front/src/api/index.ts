import axios from 'axios'
import { ElMessage } from 'element-plus'

// 后端 Spring Boot 基地址(开发期走 Vite proxy,所以用相对路径即可)
const http = axios.create({
  baseURL: '/api',
  timeout: 30000
})

http.interceptors.request.use((config) => {
  const token = localStorage.getItem('zhiyu_token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

http.interceptors.response.use(
  (resp) => resp.data,
  (err) => {
    const status = err?.response?.status
    if (status === 401 || status === 403) {
      localStorage.removeItem('zhiyu_token')
      localStorage.removeItem('zhiyu_username')
      localStorage.removeItem('zhiyu_role')
      if (window.location.pathname !== '/login') {
        window.location.assign('/login')
      }
    }
    ElMessage.error(err?.response?.data?.message || err.message || '请求失败')
    return Promise.reject(err)
  }
)

export default http
