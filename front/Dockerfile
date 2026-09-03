# ===== Stage 1: 构建 =====
FROM node:20-alpine AS builder
WORKDIR /app

# 国内构建加速(可删)
RUN npm config set registry https://registry.npmmirror.com

COPY package*.json ./
RUN npm ci || npm install

COPY . .
RUN npm run build

# ===== Stage 2: 运行 =====
FROM nginx:1.27-alpine
COPY --from=builder /app/dist-admin /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
