# ============================================================
# 智愈寻真 - 一键部署脚本（Docker 固定子网方案）
# ------------------------------------------------------------
# 用法（在 e:\zhiyu 目录下执行）:
#   powershell -ExecutionPolicy Bypass -File scripts\start-zhiyu.ps1 start
#   powershell -ExecutionPolicy Bypass -File scripts\start-zhiyu.ps1 stop
#   powershell -ExecutionPolicy Bypass -File scripts\start-zhiyu.ps1 restart
#   powershell -ExecutionPolicy Bypass -File scripts\start-zhiyu.ps1 status
#
# 说明:
#   - 所有 7 个服务放入固定子网 zhiyu-bridge (172.21.0.0/16)，
#     每个容器分配固定 IP，彻底避免 Windows Docker Desktop 的
#     DNS 解析失败与 IP 漂移问题。
#   - 容器已存在且运行中则跳过；已存在但停止则启动。
# ============================================================

$ErrorActionPreference = "Stop"

# ---------- 配置 ----------
$NetworkName = "zhiyu-bridge"
$Subnet      = "172.21.0.0/16"
$Gateway     = "172.21.0.1"

# 固定 IP
$IP = @{
    mysql   = "172.21.0.2"
    redis   = "172.21.0.3"
    etcd    = "172.21.0.4"
    minio   = "172.21.0.5"
    milvus  = "172.21.0.6"
    ai      = "172.21.0.7"
    backend = "172.21.0.8"
}

# 数据卷
$VolumeMap = @{
    mysql  = "mysql_data"
    redis  = "redis_data"
    etcd   = "etcd_data"
    minio  = "minio_data"
    milvus = "milvus_data"
}

# 项目根目录
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

# ---------- 加载 .env（敏感凭证，不被 Git 追踪） ----------
# 从项目根目录 .env 读取各 API Key，异常时回退空串，避免脚本崩溃。
function Load-EnvFile {
    $envPath = Join-Path $Root ".env"
    if (-not (Test-Path $envPath)) {
        Write-Host "[警告] 未找到 $envPath，请按 .env.example 创建并填入 API Key" -ForegroundColor Yellow
        return
    }
    Get-Content $envPath | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
            $kv = $line -split "=", 2
            $name = $kv[0].Trim()
            $value = $kv[1].Trim()
            Set-Variable -Name $name -Value $value -Scope Script
        }
    }
}
Load-EnvFile

# ---------- 工具函数 ----------
function Ensure-Network {
    $exists = docker network ls --format "{{.Name}}" | Where-Object { $_ -eq $NetworkName }
    if (-not $exists) {
        Write-Host "[创建网络] $NetworkName ($Subnet)" -ForegroundColor Cyan
        docker network create --driver bridge --subnet $Subnet --gateway $Gateway $NetworkName | Out-Null
    } else {
        Write-Host "[网络就绪] $NetworkName" -ForegroundColor DarkCyan
    }
}

function Container-State([string]$name) {
    $c = docker ps -a --filter "name=^/${name}$" --format "{{.Names}}|{{.Status}}"
    if (-not $c) { return "absent" }
    if ($c -match "Up") { return "running" }
    return "stopped"
}

function Run-Container([string]$name, [string[]]$dockerArgs) {
    $state = Container-State $name
    if ($state -eq "running") {
        Write-Host "[跳过] $name 已在运行" -ForegroundColor DarkGray
        return
    }
    if ($state -eq "stopped") {
        Write-Host "[启动] $name (已存在)" -ForegroundColor Yellow
        docker start $name | Out-Null
        return
    }
    Write-Host "[启动] $name (新建)" -ForegroundColor Green
    docker run -d --name $name @dockerArgs | Out-Null
}

# ============================================================
# 启动所有服务
# ============================================================
function Start-All {
    Ensure-Network

    # --- 基础设施 ---
    Run-Container "zhiyu-mysql" @(
        "--network", $NetworkName, "--ip", $IP.mysql,
        "-v", "${VolumeMap.mysql}:/var/lib/mysql",
        "-v", "$Root/deploy/mysql/init.sql:/docker-entrypoint-initdb.d/init.sql:ro",
        "-v", "$Root/deploy/mysql/my.cnf:/etc/mysql/conf.d/my.cnf:ro",
        "-e", "MYSQL_ROOT_PASSWORD=root123456",
        "-e", "MYSQL_DATABASE=zhiyu_db",
        "mysql:8.0"
    )

    Run-Container "zhiyu-redis" @(
        "--network", $NetworkName, "--ip", $IP.redis,
        "-v", "${VolumeMap.redis}:/data",
        "-v", "$Root/deploy/redis/redis.conf:/usr/local/etc/redis/redis.conf:ro",
        "redis:7-alpine", "redis-server", "/usr/local/etc/redis/redis.conf"
    )

    Run-Container "zhiyu-etcd" @(
        "--network", $NetworkName, "--ip", $IP.etcd,
        "-v", "${VolumeMap.etcd}:/etcd",
        "quay.io/coreos/etcd:v3.5.5", "etcd",
        "-advertise-client-urls=http://etcd:2379",
        "-listen-client-urls", "http://0.0.0.0:2379",
        "--data-dir", "/etcd"
    )

    Run-Container "zhiyu-minio" @(
        "--network", $NetworkName, "--ip", $IP.minio,
        "-v", "${VolumeMap.minio}:/minio_data",
        "-e", "MINIO_ACCESS_KEY=minioadmin",
        "-e", "MINIO_SECRET_KEY=minioadmin",
        "minio/minio:RELEASE.2024-05-10T01-41-38Z", "minio", "server", "/minio_data", "--console-address", ":9001"
    )

    # --- milvus（依赖 etcd/minio，用静态映射绕过 DNS）---
    Run-Container "zhiyu-milvus" @(
        "--network", $NetworkName, "--ip", $IP.milvus,
        "--add-host", "etcd:$($IP.etcd)",
        "--add-host", "minio:$($IP.minio)",
        "-v", "${VolumeMap.milvus}:/var/lib/milvus",
        "-v", "$Root/deploy/milvus/milvus.yaml:/milvus/configs/milvus.yaml:ro",
        "-e", "ETCD_ENDPOINTS=etcd:2379",
        "-e", "MINIO_ADDRESS=minio:9000",
        "-e", "NO_PROXY=localhost,127.0.0.1,::1,etcd,minio",
        "milvusdb/milvus:v2.4.17", "milvus", "run", "standalone"
    )

    # --- ai（依赖 milvus/redis，静态映射）---
    Run-Container "zhiyu-ai" @(
        "--network", $NetworkName, "--ip", $IP.ai,
        "--add-host", "backend:$($IP.backend)",
        "--add-host", "milvus:$($IP.milvus)",
        "--add-host", "redis:$($IP.redis)",
        "-p", "18000:8000",
        "-v", "$Root/data/objects:/app/data/objects:ro",
        "-e", "ENV_MODE=dev",
        "-e", "LLM_BASE_URL=https://api.deepseek.com", "-e", "LLM_API_KEY=$LLM_API_KEY", "-e", "LLM_MODEL=deepseek-v4-flash",
        "-e", "VISION_BASE_URL=https://ws-z7vi5mam4d8415c8.cn-beijing.maas.aliyuncs.com/compatible-mode/v1", "-e", "VISION_API_KEY=$VISION_API_KEY", "-e", "VISION_MODEL=qwen3-omni-flash",
        "-e", "EMBEDDING_BASE_URL=https://api.siliconflow.cn/v1", "-e", "EMBEDDING_API_KEY=$EMBEDDING_API_KEY", "-e", "EMBEDDING_MODEL=BAAI/bge-m3",
        "-e", "MILVUS_HOST=milvus", "-e", "MILVUS_PORT=19530",
        "-e", "MILVUS_COLLECTION=zhiyu_textbook", "-e", "MILVUS_VECTOR_DIM=1024",
        "-e", "REDIS_HOST=redis", "-e", "REDIS_PORT=6379", "-e", "REDIS_PASSWORD=",
        "-e", "AI_INTERNAL_TOKEN=dev-internal-token", "-e", "OPS_TOKEN=dev-ops-token",
        "-e", "BACKEND_CALLBACK_URL=http://backend:8080",
        "-e", "ENABLE_LLM_FALLBACK=false", "-e", "ENABLE_MILVUS_FALLBACK=true",
        "-e", "NO_PROXY=localhost,127.0.0.1,::1,mysql,redis,etcd,minio,milvus,backend,ai",
        "zhiyu-ai:latest"
    )

    # --- backend（依赖 mysql/redis/ai，静态映射）---
    Run-Container "zhiyu-backend" @(
        "--network", $NetworkName, "--ip", $IP.backend,
        "--add-host", "mysql:$($IP.mysql)",
        "--add-host", "redis:$($IP.redis)",
        "--add-host", "ai:$($IP.ai)",
        "-p", "18080:8080",
        "-v", "$Root/logs/backend:/app/logs",
        "-e", "SPRING_PROFILE=dev",
        "-e", "DB_HOST=mysql", "-e", "DB_PORT=3306", "-e", "DB_USER=root",
        "-e", "DB_PASSWORD=root123456", "-e", "MYSQL_DATABASE=zhiyu_db",
        "-e", "REDIS_HOST=redis", "-e", "REDIS_PORT=6379", "-e", "REDIS_PASSWORD=",
        "-e", "JWT_SECRET=dev-only-secret-key-32chars-minimum-aaaa", "-e", "JWT_EXPIRE_HOURS=24",
        "-e", "AI_BASE_URL=http://ai:8000", "-e", "AI_INTERNAL_TOKEN=dev-internal-token",
        "-e", "NO_PROXY=localhost,127.0.0.1,::1,mysql,redis,etcd,minio,milvus,backend,ai",
        "zhiyu-backend:latest"
    )

    Write-Host "`n所有服务已启动，等待健康检查..." -ForegroundColor Cyan
    Wait-Healthy
}

# ---------- 健康检查 ----------
function Wait-Healthy {
    $deadline = (Get-Date).AddSeconds(90)
    $ok = $false
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 5
        try {
            $h = Invoke-RestMethod -Uri "http://localhost:18080/api/v1/health" -TimeoutSec 5
            if ($h.data.status -eq "UP" -and $h.data.db -eq "UP") { $ok = $true; break }
        } catch {
            # 未就绪，继续等
        }
    }
    if ($ok) {
        Write-Host "[健康检查] 后端 UP + DB UP " -ForegroundColor Green
        try {
            $ai = Invoke-RestMethod -Uri "http://localhost:18000/health" -TimeoutSec 5
            Write-Host "[健康检查] AI UP" -ForegroundColor Green
        } catch { Write-Host "[警告] AI 未就绪" -ForegroundColor Yellow }
    } else {
        Write-Host "[失败] 后端未在 90 秒内就绪，请查看日志: docker logs zhiyu-backend" -ForegroundColor Red
    }
}

# ---------- 停止 ----------
function Stop-All {
    $names = @("zhiyu-backend","zhiyu-ai","zhiyu-milvus","zhiyu-minio","zhiyu-etcd","zhiyu-redis","zhiyu-mysql")
    foreach ($n in $names) {
        $state = Container-State $n
        if ($state -eq "running") {
            Write-Host "[停止] $n" -ForegroundColor Yellow
            docker stop $n | Out-Null
        }
    }
    Write-Host "所有服务已停止" -ForegroundColor Green
}

# ---------- 状态 ----------
function Show-Status {
    Write-Host "`n===== 容器状态 =====" -ForegroundColor Cyan
    docker ps -a --format "table {{.Names}}`t{{.Status}}" | Where-Object { $_ -match "zhiyu|NAMES" }
    Write-Host "`n===== 健康检查 =====" -ForegroundColor Cyan
    try {
        $h = Invoke-RestMethod -Uri "http://localhost:18080/api/v1/health" -TimeoutSec 5
        Write-Host "backend: UP (db=$($h.data.db))" -ForegroundColor Green
    } catch { Write-Host "backend: DOWN" -ForegroundColor Red }
    try {
        $a = Invoke-RestMethod -Uri "http://localhost:18000/health" -TimeoutSec 5
        Write-Host "ai: $($a.status)" -ForegroundColor Green
    } catch { Write-Host "ai: DOWN" -ForegroundColor Red }
}

# ---------- 主入口 ----------
$action = $args[0]
if (-not $action) { $action = "start" }

switch ($action.ToLower()) {
    "start"   { Start-All }
    "stop"    { Stop-All }
    "restart" { Stop-All; Start-Sleep -Seconds 3; Start-All }
    "status"  { Show-Status }
    default   { Write-Host "用法: $($MyInvocation.MyCommand.Name) [start|stop|restart|status]" -ForegroundColor Yellow }
}