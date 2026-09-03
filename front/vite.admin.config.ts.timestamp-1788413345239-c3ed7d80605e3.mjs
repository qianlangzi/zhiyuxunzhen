// vite.admin.config.ts
import { defineConfig, loadEnv } from "file:///E:/zhiyu/front/node_modules/vite/dist/node/index.js";
import vue from "file:///E:/zhiyu/front/node_modules/@vitejs/plugin-vue/dist/index.mjs";
import { fileURLToPath, URL } from "node:url";
var __vite_injected_original_import_meta_url = "file:///E:/zhiyu/front/vite.admin.config.ts";
var adminRoot = fileURLToPath(new URL("./admin", __vite_injected_original_import_meta_url));
var vite_admin_config_default = defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");
  return {
    root: adminRoot,
    publicDir: fileURLToPath(new URL("./public", __vite_injected_original_import_meta_url)),
    plugins: [vue()],
    build: {
      outDir: fileURLToPath(new URL("./dist-admin", __vite_injected_original_import_meta_url)),
      emptyOutDir: true
    },
    resolve: {
      alias: {
        "@": fileURLToPath(new URL("./src", __vite_injected_original_import_meta_url))
      }
    },
    server: {
      host: "0.0.0.0",
      port: Number(env.ADMIN_FRONT_PORT) || 5174,
      proxy: {
        "/api": {
          target: env.VITE_API_BASE || "http://backend:8080",
          changeOrigin: true
          // 不 rewrite：后端 Controller 路径含 /api/v1 前缀（context-path=/），
          // 保留 /api 原样转发，否则 /api/v1/auth/login 会变成 /v1/auth/login 导致 404
        },
        "/ai": {
          target: env.VITE_AI_BASE || "http://ai:8000",
          changeOrigin: true,
          rewrite: (path) => path.replace(/^\/ai/, "")
        }
      }
    }
  };
});
export {
  vite_admin_config_default as default
};
//# sourceMappingURL=data:application/json;base64,ewogICJ2ZXJzaW9uIjogMywKICAic291cmNlcyI6IFsidml0ZS5hZG1pbi5jb25maWcudHMiXSwKICAic291cmNlc0NvbnRlbnQiOiBbImNvbnN0IF9fdml0ZV9pbmplY3RlZF9vcmlnaW5hbF9kaXJuYW1lID0gXCJFOlxcXFx6aGl5dVxcXFxmcm9udFwiO2NvbnN0IF9fdml0ZV9pbmplY3RlZF9vcmlnaW5hbF9maWxlbmFtZSA9IFwiRTpcXFxcemhpeXVcXFxcZnJvbnRcXFxcdml0ZS5hZG1pbi5jb25maWcudHNcIjtjb25zdCBfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfaW1wb3J0X21ldGFfdXJsID0gXCJmaWxlOi8vL0U6L3poaXl1L2Zyb250L3ZpdGUuYWRtaW4uY29uZmlnLnRzXCI7aW1wb3J0IHsgZGVmaW5lQ29uZmlnLCBsb2FkRW52IH0gZnJvbSAndml0ZSdcclxuaW1wb3J0IHZ1ZSBmcm9tICdAdml0ZWpzL3BsdWdpbi12dWUnXHJcbmltcG9ydCB7IGZpbGVVUkxUb1BhdGgsIFVSTCB9IGZyb20gJ25vZGU6dXJsJ1xyXG5cclxuY29uc3QgYWRtaW5Sb290ID0gZmlsZVVSTFRvUGF0aChuZXcgVVJMKCcuL2FkbWluJywgaW1wb3J0Lm1ldGEudXJsKSlcclxuXHJcbmV4cG9ydCBkZWZhdWx0IGRlZmluZUNvbmZpZygoeyBtb2RlIH0pID0+IHtcclxuICBjb25zdCBlbnYgPSBsb2FkRW52KG1vZGUsIHByb2Nlc3MuY3dkKCksICcnKVxyXG4gIHJldHVybiB7XHJcbiAgICByb290OiBhZG1pblJvb3QsXHJcbiAgICBwdWJsaWNEaXI6IGZpbGVVUkxUb1BhdGgobmV3IFVSTCgnLi9wdWJsaWMnLCBpbXBvcnQubWV0YS51cmwpKSxcclxuICAgIHBsdWdpbnM6IFt2dWUoKV0sXHJcbiAgICBidWlsZDoge1xyXG4gICAgICBvdXREaXI6IGZpbGVVUkxUb1BhdGgobmV3IFVSTCgnLi9kaXN0LWFkbWluJywgaW1wb3J0Lm1ldGEudXJsKSksXHJcbiAgICAgIGVtcHR5T3V0RGlyOiB0cnVlXHJcbiAgICB9LFxyXG4gICAgcmVzb2x2ZToge1xyXG4gICAgICBhbGlhczoge1xyXG4gICAgICAgICdAJzogZmlsZVVSTFRvUGF0aChuZXcgVVJMKCcuL3NyYycsIGltcG9ydC5tZXRhLnVybCkpXHJcbiAgICAgIH1cclxuICAgIH0sXHJcbiAgICBzZXJ2ZXI6IHtcclxuICAgICAgaG9zdDogJzAuMC4wLjAnLFxyXG4gICAgICBwb3J0OiBOdW1iZXIoZW52LkFETUlOX0ZST05UX1BPUlQpIHx8IDUxNzQsXHJcbiAgICAgIHByb3h5OiB7XHJcbiAgICAgICAgJy9hcGknOiB7XHJcbiAgICAgICAgICB0YXJnZXQ6IGVudi5WSVRFX0FQSV9CQVNFIHx8ICdodHRwOi8vYmFja2VuZDo4MDgwJyxcclxuICAgICAgICAgIGNoYW5nZU9yaWdpbjogdHJ1ZSxcclxuICAgICAgICAgIC8vIFx1NEUwRCByZXdyaXRlXHVGRjFBXHU1NDBFXHU3QUVGIENvbnRyb2xsZXIgXHU4REVGXHU1Rjg0XHU1NDJCIC9hcGkvdjEgXHU1MjREXHU3RjAwXHVGRjA4Y29udGV4dC1wYXRoPS9cdUZGMDlcdUZGMENcclxuICAgICAgICAgIC8vIFx1NEZERFx1NzU1OSAvYXBpIFx1NTM5Rlx1NjgzN1x1OEY2Q1x1NTNEMVx1RkYwQ1x1NTQyNlx1NTIxOSAvYXBpL3YxL2F1dGgvbG9naW4gXHU0RjFBXHU1M0Q4XHU2MjEwIC92MS9hdXRoL2xvZ2luIFx1NUJGQ1x1ODFGNCA0MDRcclxuICAgICAgICB9LFxyXG4gICAgICAgICcvYWknOiB7XHJcbiAgICAgICAgICB0YXJnZXQ6IGVudi5WSVRFX0FJX0JBU0UgfHwgJ2h0dHA6Ly9haTo4MDAwJyxcclxuICAgICAgICAgIGNoYW5nZU9yaWdpbjogdHJ1ZSxcclxuICAgICAgICAgIHJld3JpdGU6IChwYXRoKSA9PiBwYXRoLnJlcGxhY2UoL15cXC9haS8sICcnKVxyXG4gICAgICAgIH1cclxuICAgICAgfVxyXG4gICAgfVxyXG4gIH1cclxufSlcclxuIl0sCiAgIm1hcHBpbmdzIjogIjtBQUE4TyxTQUFTLGNBQWMsZUFBZTtBQUNwUixPQUFPLFNBQVM7QUFDaEIsU0FBUyxlQUFlLFdBQVc7QUFGNEcsSUFBTSwyQ0FBMkM7QUFJaE0sSUFBTSxZQUFZLGNBQWMsSUFBSSxJQUFJLFdBQVcsd0NBQWUsQ0FBQztBQUVuRSxJQUFPLDRCQUFRLGFBQWEsQ0FBQyxFQUFFLEtBQUssTUFBTTtBQUN4QyxRQUFNLE1BQU0sUUFBUSxNQUFNLFFBQVEsSUFBSSxHQUFHLEVBQUU7QUFDM0MsU0FBTztBQUFBLElBQ0wsTUFBTTtBQUFBLElBQ04sV0FBVyxjQUFjLElBQUksSUFBSSxZQUFZLHdDQUFlLENBQUM7QUFBQSxJQUM3RCxTQUFTLENBQUMsSUFBSSxDQUFDO0FBQUEsSUFDZixPQUFPO0FBQUEsTUFDTCxRQUFRLGNBQWMsSUFBSSxJQUFJLGdCQUFnQix3Q0FBZSxDQUFDO0FBQUEsTUFDOUQsYUFBYTtBQUFBLElBQ2Y7QUFBQSxJQUNBLFNBQVM7QUFBQSxNQUNQLE9BQU87QUFBQSxRQUNMLEtBQUssY0FBYyxJQUFJLElBQUksU0FBUyx3Q0FBZSxDQUFDO0FBQUEsTUFDdEQ7QUFBQSxJQUNGO0FBQUEsSUFDQSxRQUFRO0FBQUEsTUFDTixNQUFNO0FBQUEsTUFDTixNQUFNLE9BQU8sSUFBSSxnQkFBZ0IsS0FBSztBQUFBLE1BQ3RDLE9BQU87QUFBQSxRQUNMLFFBQVE7QUFBQSxVQUNOLFFBQVEsSUFBSSxpQkFBaUI7QUFBQSxVQUM3QixjQUFjO0FBQUE7QUFBQTtBQUFBLFFBR2hCO0FBQUEsUUFDQSxPQUFPO0FBQUEsVUFDTCxRQUFRLElBQUksZ0JBQWdCO0FBQUEsVUFDNUIsY0FBYztBQUFBLFVBQ2QsU0FBUyxDQUFDLFNBQVMsS0FBSyxRQUFRLFNBQVMsRUFBRTtBQUFBLFFBQzdDO0FBQUEsTUFDRjtBQUFBLElBQ0Y7QUFBQSxFQUNGO0FBQ0YsQ0FBQzsiLAogICJuYW1lcyI6IFtdCn0K
