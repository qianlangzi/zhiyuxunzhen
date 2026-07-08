import { createApp } from 'vue'
import ElementPlus from 'element-plus'
import 'element-plus/dist/index.css'
import * as ElementPlusIconsVue from '@element-plus/icons-vue'
import AdminApp from './AdminApp.vue'
import adminRouter from './router'
import '@/styles/main.css'
import './styles.css'

const app = createApp(AdminApp)

for (const [key, component] of Object.entries(ElementPlusIconsVue)) {
  app.component(key, component as any)
}

app.use(adminRouter)
app.use(ElementPlus)
app.mount('#admin-app')
