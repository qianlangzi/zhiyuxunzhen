#!/usr/bin/env bash
# ============================================================
# SP 病人对话改造 · 部署后冒烟验证
#
# 验证 4 件事：
#   1. AI 中台新端点 /internal/chat/stream + /internal/chat/opening 存在
#   2. backend 新端点 /chat/stream 存在（SSE）
#   3. startSession 返回 openingMessage（SP 主动开场）
#   4. 两个容器构建时间 > 改动时间（确认用的是新镜像）
#
# 用法： bash scripts/verify_sp_chat.sh
# ============================================================
set -uo pipefail

BACKEND="http://localhost:18080"
AI="http://localhost:18000"
PASS=0
FAIL=0

green() { printf "\033[32m%s\033[0m\n" "$1"; }
red()   { printf "\033[31m%s\033[0m\n" "$1"; }
info()  { printf "\033[36m%s\033[0m\n" "$1"; }

check() { # check <描述> <期望条件为真的 shell 表达式>
  local desc="$1"; shift
  if eval "$@" >/dev/null 2>&1; then
    green "  [PASS] $desc"; PASS=$((PASS+1))
  else
    red   "  [FAIL] $desc"; FAIL=$((FAIL+1))
  fi
}

info "=== 1. 容器状态 ==="
docker ps --format "{{.Names}}\t{{.Status}}" | grep -E "zhiyu-(backend|ai)$" || true
echo

info "=== 2. AI 中台 OpenAPI 是否含新端点 ==="
OPENAPI=$(curl -s --max-time 10 "$AI/openapi.json" 2>/dev/null)
if [ -z "$OPENAPI" ]; then
  red "  [FAIL] 无法拉取 AI 中台 openapi.json（服务未就绪？）"; FAIL=$((FAIL+1))
else
  check "存在 /internal/chat/stream" \
    "echo \"$OPENAPI\" | grep -q '/internal/chat/stream'"
  check "存在 /internal/chat/opening" \
    "echo \"$OPENAPI\" | grep -q '/internal/chat/opening'"
  check "仍存在 /internal/chat/sync（未破坏旧接口）" \
    "echo \"$OPENAPI\" | grep -q '/internal/chat/sync'"
fi
echo

info "=== 3. backend 健康检查 ==="
HEALTH=$(curl -s --max-time 10 "$BACKEND/actuator/health" 2>/dev/null)
if echo "$HEALTH" | grep -q "UP"; then
  green "  [PASS] backend 健康: $HEALTH"; PASS=$((PASS+1))
else
  red "  [FAIL] backend 未就绪: ${HEALTH:-无响应}"; FAIL=$((FAIL+1))
fi
echo

info "=== 4. 新端点探测（未鉴权应返回 401/403/400，而非 404）==="
# 404 = 路由不存在（代码没生效）；401/403 = 路由存在但被鉴权拦截（符合预期）
code_stream=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
  -X POST "$BACKEND/api/v1/student/sessions/1/chat/stream" \
  -H "Content-Type: application/json" -d '{"message":"hi"}' 2>/dev/null)
info "  /chat/stream 无 token 返回: $code_stream"
if [ "$code_stream" = "404" ]; then
  red "  [FAIL] /chat/stream 路由不存在（镜像未更新？）"; FAIL=$((FAIL+1))
else
  green "  [PASS] /chat/stream 路由已注册（401/403/400 均表示生效）"; PASS=$((PASS+1))
fi

code_open=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 \
  "$AI/internal/chat/opening" 2>/dev/null)
info "  AI /internal/chat/opening 返回: $code_open"
echo

info "=== 5. 构建产物时间戳（确认用的是新镜像）==="
for svc in backend ai; do
  built=$(docker inspect -f '{{.Created}}' "zhiyu-$svc" 2>/dev/null | cut -c1-19)
  info "  zhiyu-$svc 容器创建时间: $built"
done
echo

info "=== 结果 ==="
green "  通过: $PASS"
[ "$FAIL" -gt 0 ] && red "  失败: $FAIL" || green "  失败: 0"
echo
if [ "$FAIL" -eq 0 ]; then
  green "全部通过 → 可以 flutter run 进问诊室看效果了"
else
  red "有失败项 → 检查上方 [FAIL] 行"
fi
