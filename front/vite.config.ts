import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'
import { fileURLToPath, URL } from 'node:url'

const appHtml = fileURLToPath(new URL('./index.html', import.meta.url))

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  return {
    plugins: [vue()],
    build: {
      rollupOptions: {
        input: {
          app: appHtml
        }
      }
    },
    resolve: {
      alias: {
        '@': fileURLToPath(new URL('./src', import.meta.url))
      }
    },
    server: {
      host: '0.0.0.0',
      port: Number(env.FRONT_PORT) || 5173,
      // 开发期通过 Vite 代理转发到后端,避免浏览器跨域
      proxy: {
        '/api': {
          target: env.VITE_API_BASE || 'http://backend:8080',
          changeOrigin: true,
          rewrite: (path) => path.replace(/^\/api/, '')
        },
        '/ai': {
          target: env.VITE_AI_BASE || 'http://ai:8000',
          changeOrigin: true,
          rewrite: (path) => path.replace(/^\/ai/, '')
        }
      }
    }
  }
})
