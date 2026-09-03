import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'
import { fileURLToPath, URL } from 'node:url'

const adminRoot = fileURLToPath(new URL('./admin', import.meta.url))

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  return {
    root: adminRoot,
    publicDir: fileURLToPath(new URL('./public', import.meta.url)),
    plugins: [vue()],
    build: {
      outDir: fileURLToPath(new URL('./dist-admin', import.meta.url)),
      emptyOutDir: true
    },
    resolve: {
      alias: {
        '@': fileURLToPath(new URL('./src', import.meta.url))
      }
    },
    server: {
      host: '0.0.0.0',
      port: Number(env.ADMIN_FRONT_PORT) || 5174,
      proxy: {
        '/api': {
          target: env.VITE_API_BASE || 'http://backend:8080',
          changeOrigin: true,
          // 不 rewrite：后端 Controller 路径含 /api/v1 前缀（context-path=/），
          // 保留 /api 原样转发，否则 /api/v1/auth/login 会变成 /v1/auth/login 导致 404
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
