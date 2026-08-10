﻿﻿﻿# ============================================================
# 智愈寻真 · 端到端测试脚本（学生端 + AI 问诊全链路）
# 依赖：后端 8080 / AI 8000 已通过 Docker 运行
# 用法：powershell -ExecutionPolicy Bypass -File e2e_test.ps1
# ============================================================

$BASE = "http://localhost:8080/api/v1"
$AI   = "http://localhost:8000"
$studentToken = $null

# ---- 结果统计 ----
$script:pass = 0
$script:fail = 0
$script:failures = @()

function Log-Pass([string]$name) {
    $script:pass++
    Write-Host "[PASS] $name" -ForegroundColor Green
}
function Log-Fail([string]$name, [string]$detail) {
    $script:fail++
    $script:failures += "$name :: $detail"
    Write-Host "[FAIL] $name :: $detail" -ForegroundColor Red
}
function Invoke-Api([string]$method, [string]$path, $body = $null, [bool]$auth = $false) {
    $uri = "$BASE$path"
    $headers = @{}
    if ($auth -and $studentToken) { $headers["Authorization"] = "Bearer $studentToken" }
    try {
        if ($body -ne $null) {
            $json = $body | ConvertTo-Json -Depth 12
            return Invoke-RestMethod -Uri $uri -Method $method -ContentType "application/json" -Headers $headers -Body $json -TimeoutSec 30
        }
        return Invoke-RestMethod -Uri $uri -Method $method -Headers $headers -TimeoutSec 30
    } catch {
        $detail = $_.Exception.Message
        if ($_.ErrorDetails) { $detail = $_.ErrorDetails.Message }
        return @{ code = -1; message = $detail }
    }
}

# ============================================================
# 0. 健康检查
# ============================================================
Write-Host "`n===== 0. 健康检查 =====" -ForegroundColor Cyan
try {
    $h = Invoke-RestMethod -Uri "$BASE/health" -TimeoutSec 10
    if ($h.data.status -eq "UP" -and $h.data.db -eq "UP") { Log-Pass "后端健康检查 UP + DB UP" }
    else { Log-Fail "后端健康检查" ($h.data | ConvertTo-Json -Compress) }
} catch { Log-Fail "后端健康检查" $_.Exception.Message }

try {
    $ah = Invoke-RestMethod -Uri "$AI/health" -TimeoutSec 10
    if ($ah.status -eq "UP") { Log-Pass "AI 健康检查 UP" }
    else { Log-Fail "AI 健康检查" ($ah | ConvertTo-Json -Compress) }
} catch { Log-Fail "AI 健康检查" $_.Exception.Message }

# ============================================================
# 1. 学生登录
# ============================================================
Write-Host "`n===== 1. 学生登录 =====" -ForegroundColor Cyan
$loginBody = @{ username = "student01"; password = "123456" }
$login = Invoke-Api "Post" "/auth/login/password" $loginBody
if ($login.code -eq 0 -and $login.data.token) {
    $studentToken = $login.data.token
    Log-Pass "学生登录 student01 (userId=$($login.data.userId))"
} else { Log-Fail "学生登录" ($login | ConvertTo-Json -Compress) }

# ============================================================
# 2. 作业（我的 + 待办 + 详情）
# ============================================================
Write-Host "`n===== 2. 作业接口 =====" -ForegroundColor Cyan
$myAsg = Invoke-Api "Get" "/student/assignments/my?pageSize=10" $null $true
if ($myAsg.code -eq 0) {
    Log-Pass "我的作业列表 (total=$($myAsg.data.total))"
    $asgList = @($myAsg.data.list)
    if ($asgList.Count -gt 0) {
        $asgId = $asgList[0].instanceId
        $todoAsg = Invoke-Api "Get" "/student/assignments/todo?pageSize=10" $null $true
        if ($todoAsg.code -eq 0) { Log-Pass "待办作业列表 (total=$($todoAsg.data.total))" }
        else { Log-Fail "待办作业列表" ($todoAsg | ConvertTo-Json -Compress) }
        $asgDetail = Invoke-Api "Get" "/student/assignments/$asgId" $null $true
        if ($asgDetail.code -eq 0) { Log-Pass "作业详情 id=$asgId" }
        else { Log-Fail "作业详情" ($asgDetail | ConvertTo-Json -Compress) }
    } else { Log-Fail "作业列表为空，无法继续" "myAssignments empty" }
} else { Log-Fail "我的作业列表" ($myAsg | ConvertTo-Json -Compress) }

# ============================================================
# 3. 教材中心（科室 + 列表 + 详情 + fileUrl）
# ============================================================
Write-Host "`n===== 3. 教材中心 =====" -ForegroundColor Cyan
$tbDept = Invoke-Api "Get" "/student/textbooks/departments" $null $true
if ($tbDept.code -eq 0) {
    Log-Pass "教材科室列表 (count=$($tbDept.data.Count))"
    $tbList = Invoke-Api "Get" "/student/textbooks?pageSize=20" $null $true
    if ($tbList.code -eq 0 -and @($tbList.data.list).Count -gt 0) {
        $tbId = $tbList.data.list[0].id
        $hasFile = $null -ne $tbList.data.list[0].fileUrl -and $tbList.data.list[0].fileUrl -ne ""
        if ($hasFile) { Log-Pass "教材列表含 fileUrl (电子书)" } else { Log-Fail "教材列表缺少 fileUrl" ($tbList.data.list[0] | ConvertTo-Json -Compress) }
        $tbDetail = Invoke-Api "Get" "/student/textbooks/$tbId" $null $true
        if ($tbDetail.code -eq 0) { Log-Pass "教材详情 id=$tbId ($($tbDetail.data.title))" }
        else { Log-Fail "教材详情" ($tbDetail | ConvertTo-Json -Compress) }
    } else { Log-Fail "教材列表为空" ($tbList | ConvertTo-Json -Compress) }
} else { Log-Fail "教材科室列表" ($tbDept | ConvertTo-Json -Compress) }

# ============================================================
# 4. 基础题训练（科室 + 按科室刷题 + 提交）
# ============================================================
Write-Host "`n===== 4. 基础题训练 =====" -ForegroundColor Cyan
$qDept = Invoke-Api "Get" "/student/questions/departments" $null $true
if ($qDept.code -eq 0) {
    Log-Pass "刷题科室列表 (count=$($qDept.data.Count))"
    # 注意：PowerShell 5 的 Invoke-RestMethod 会把响应中文按非 UTF-8 解码，导致动态取出的科室名损坏。
    # 故此处用字面量科室名（数据库确认"心血管内科"存在 9 题）进行刷题接口验证。
    $dept = "心血管内科"
    $qPage = Invoke-Api "Get" "/student/questions/by-department?pageNum=1&pageSize=1&department=$dept" $null $true
    if ($qPage.code -eq 0 -and @($qPage.data.list).Count -gt 0) {
        Log-Pass "按科室[$dept]刷题 (total=$($qPage.data.total))"
        $q = $qPage.data.list[0]
        $submitBody = @{ questionId = $q.id; selectedAnswer = "0" }
        $submit = Invoke-Api "Post" "/student/questions/submit" $submitBody $true
        if ($submit.code -eq 0) { Log-Pass "提交答案判题 (correct=$($submit.data.correct))" }
        else { Log-Fail "提交答案判题" ($submit | ConvertTo-Json -Compress) }
    } else { Log-Fail "按科室刷题" ($qPage | ConvertTo-Json -Compress) }
    $qStats = Invoke-Api "Get" "/student/questions/stats" $null $true
    if ($qStats.code -eq 0) { Log-Pass "训练统计" }
    else { Log-Fail "训练统计" ($qStats | ConvertTo-Json -Compress) }
} else { Log-Fail "刷题科室列表" ($qDept | ConvertTo-Json -Compress) }

# ============================================================
# 5. 错题本
# ============================================================
Write-Host "`n===== 5. 错题本 =====" -ForegroundColor Cyan
$mistakes = Invoke-Api "Get" "/student/mistakes?pageSize=10" $null $true
if ($mistakes.code -eq 0) { Log-Pass "错题本列表 (total=$($mistakes.data.total))" }
else { Log-Fail "错题本列表" ($mistakes | ConvertTo-Json -Compress) }

# ============================================================
# 6. 智能推荐（薄弱点 + 全局检索）
# ============================================================
Write-Host "`n===== 6. 智能推荐 =====" -ForegroundColor Cyan
$rec = Invoke-Api "Get" "/student/recommend/weaknesses" $null $true
if ($rec.code -eq 0) { Log-Pass "薄弱点推荐列表 (count=$($rec.data.Count))" }
else { Log-Fail "薄弱点推荐列表" ($rec | ConvertTo-Json -Compress) }
$search = Invoke-Api "Get" "/student/recommend/search?keyword=%E8%83%B8%E7%97%9B" $null $true
if ($search.code -eq 0) { Log-Pass "全局检索'胸痛' (textbooks=$($search.data.textbooks.Count) questions=$($search.data.questions.Count))" }
else { Log-Fail "全局检索" ($search | ConvertTo-Json -Compress) }

# ============================================================
# 7. 复盘报告（热力图 + 概览）
# ============================================================
Write-Host "`n===== 7. 复盘报告 / 热力图 =====" -ForegroundColor Cyan
$overview = Invoke-Api "Get" "/student/review-report/overview" $null $true
if ($overview.code -eq 0) {
    Log-Pass "复盘概览 (能力分=$($overview.data.abilityScore))"
    if ($null -ne $overview.data.activityDays) { Log-Pass "学习热力图返回 (天数=$($overview.data.activityDays.Count))" }
    else { Log-Fail "学习热力图缺失" ($overview.data | ConvertTo-Json -Compress) }
} else { Log-Fail "复盘概览" ($overview | ConvertTo-Json -Compress) }

# ============================================================
# 8. OSCE 历史记录
# ============================================================
Write-Host "`n===== 8. OSCE 历史 =====" -ForegroundColor Cyan
$osce = Invoke-Api "Get" "/student/evaluations/history" $null $true
if ($osce.code -eq 0) { Log-Pass "OSCE 历史记录 (count=$($osce.data.Count))" }
else { Log-Fail "OSCE 历史记录" ($osce | ConvertTo-Json -Compress) }

# ============================================================
# 9. AI 问诊全链路（启动 → 发消息 → RAG引用 → 结束）
# ============================================================
Write-Host "`n===== 9. AI 问诊全链路 =====" -ForegroundColor Cyan
$start = Invoke-Api "Post" "/student/sessions" @{ caseId = 1 } $true
if ($start.code -eq 0 -and $start.data.sessionId) {
    $sid = $start.data.sessionId
    Log-Pass "启动问诊会话 sessionId=$sid"
    # 发送问诊消息
    $msgBody = @{ message = "医生您好，我胸口疼，能帮我看看吗？" }
    $chat = Invoke-Api "Post" "/student/sessions/$sid/chat" $msgBody $true
    if ($chat.code -eq 0) {
        $hasReply = $null -ne $chat.data.reply -and $chat.data.reply -ne ""
        $hasCites = $null -ne $chat.data.citations -and $chat.data.citations.Count -gt 0
        if ($hasReply) { Log-Pass "AI 问诊回复成功 (len=$($chat.data.reply.Length))" } else { Log-Fail "AI 问诊无回复" ($chat.data | ConvertTo-Json -Compress) }
        if ($hasCites) { Log-Pass "RAG 教材引用 (count=$($chat.data.citations.Count))" } else { Write-Host "[INFO] 无 RAG 引用（可能未配置 embedding）" -ForegroundColor Yellow }
        Write-Host ("      reply=" + $chat.data.reply.Substring(0, [Math]::Min(60, $chat.data.reply.Length)) + "...") -ForegroundColor DarkGray
    } else { Log-Fail "AI 问诊发送消息" ($chat | ConvertTo-Json -Compress) }
    # 结束会话
    $finish = Invoke-Api "Post" "/student/sessions/$sid/finish" $null $true
    if ($finish.code -eq 0) { Log-Pass "结束问诊会话" } else { Log-Fail "结束问诊会话" ($finish | ConvertTo-Json -Compress) }
    # OSCE 评估
    $eval = Invoke-Api "Get" "/student/evaluations/$sid" $null $true
    if ($eval.code -eq 0) { Log-Pass "OSCE 评估结果 (总分=$($eval.data.totalScore))" }
    else { Log-Fail "OSCE 评估结果" ($eval | ConvertTo-Json -Compress) }
} else { Log-Fail "启动问诊会话" ($start | ConvertTo-Json -Compress) }

# ============================================================
# 汇总
# ============================================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "端到端测试结果：PASS=$script:pass  FAIL=$script:fail" -ForegroundColor $(if ($script:fail -eq 0) { "Green" } else { "Red" })
Write-Host "========================================" -ForegroundColor Cyan
if ($script:failures.Count -gt 0) {
    Write-Host "`n失败项：" -ForegroundColor Red
    $script:failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
}
exit $script:fail
