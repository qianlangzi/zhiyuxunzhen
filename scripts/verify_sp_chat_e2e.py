#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""SP 病人对话改造 · 端到端冒烟验证

验证链路：
  1. 登录 student01 拿 JWT
  2. 找一个可执行病例（公开 / 今日每日一例 / 已分配）
  3. POST /api/v1/student/sessions  → 检查返回 openingMessage（SP 主动开场白）
  4. POST /{sid}/chat/stream        → 检查 SSE 流式事件（打字机数据源）
  5. 对照 /{sid}/chat （同步）      → 确认旧接口仍可用

用法：
  python scripts/verify_sp_chat_e2e.py
"""
import json
import sys
import time
import urllib.error
import urllib.request

BASE = "http://localhost:18080"
USERNAME = "student01"
PASSWORD = "123456"

PASS = 0
FAIL = 0


def green(s):
    print(f"\033[32m{s}\033[0m")


def red(s):
    print(f"\033[31m{s}\033[0m")


def info(s):
    print(f"\033[36m{s}\033[0m")


def check(desc, ok, detail=""):
    global PASS, FAIL
    if ok:
        green(f"  [PASS] {desc}")
        if detail:
            print(f"         {detail}")
        PASS += 1
    else:
        red(f"  [FAIL] {desc}")
        if detail:
            print(f"         {detail}")
        FAIL += 1


def http(method, path, token=None, body=None, timeout=90, stream=False):
    url = BASE + path
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    if stream:
        req.add_header("Accept", "text/event-stream")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
            return resp.status, raw
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", errors="replace")
    except Exception as e:  # noqa: BLE001
        return -1, str(e)


def main():
    info("=== 1. 登录 ===")
    code, raw = http("POST", "/api/v1/auth/login",
                     body={"username": USERNAME, "password": PASSWORD})
    if code != 200:
        red(f"  登录失败 HTTP {code}: {raw[:300]}")
        sys.exit(1)
    d = json.loads(raw)
    if d.get("code") != 0:
        red(f"  登录失败: {d.get('message')}")
        sys.exit(1)
    data = d.get("data") or {}
    token = data.get("token", "")
    green(f"  [PASS] 登录成功 userId={data.get('userId')} ({data.get('realName')})")
    global PASS
    PASS += 1

    # ---------------- 2. 找病例 ----------------
    info("\n=== 2. 查找可执行病例 ===")
    case_id = None
    # 2.1 今日每日一例
    code, raw = http("GET", "/api/v1/student/daily-cases/today", token, timeout=30)
    if code == 200:
        try:
            dd = json.loads(raw)
            c = (dd.get("data") or {})
            cid = c.get("caseId") or c.get("id")
            if cid:
                case_id = int(cid)
                info(f"  命中今日每日一例 caseId={case_id}")
        except Exception:  # noqa: BLE001
            pass
    # 2.2 病例大厅
    if case_id is None:
        for p in ("/api/v1/student/cases?pageNum=1&pageSize=20",
                  "/api/v1/case-market?pageNum=1&pageSize=20",
                  "/api/v1/student/cases/market?pageNum=1&pageSize=20"):
            code, raw = http("GET", p, token, timeout=30)
            if code != 200:
                continue
            try:
                dd = json.loads(raw)
                body = dd.get("data") or {}
                lst = body.get("list") or body.get("records") or []
                for c in lst:
                    cid = c.get("id") or c.get("caseId")
                    if cid:
                        case_id = int(cid)
                        info(f"  命中病例大厅 caseId={case_id} ({c.get('title')})")
                        break
            except Exception:  # noqa: BLE001
                continue
            if case_id:
                break
    if case_id is None:
        red("  [FAIL] 找不到任何可执行病例，无法继续端到端验证")
        red("         → 请先在管理端发布一个公开病例，或设置今日每日一例")
        sys.exit(1)
    check("找到可执行病例", True, f"caseId={case_id}")

    # ---------------- 3. startSession → openingMessage ----------------
    info("\n=== 3. startSession → SP 主动开场白 ===")
    t0 = time.time()
    code, raw = http("POST", "/api/v1/student/sessions", token,
                     body={"caseId": case_id}, timeout=120)
    cost = time.time() - t0
    if code != 200:
        red(f"  [FAIL] startSession HTTP {code}: {raw[:300]}")
        sys.exit(1)
    d = json.loads(raw)
    if d.get("code") != 0:
        red(f"  [FAIL] startSession 业务失败: {d.get('message')}")
        sys.exit(1)
    sd = d.get("data") or {}
    sid = sd.get("sessionId")
    opening = sd.get("openingMessage")
    degraded = sd.get("openingDegraded")
    check("返回 sessionId", sid is not None, f"sessionId={sid}")
    check("返回 openingMessage 字段", opening is not None and opening != "",
          f"开场白 = 「{opening}」")
    info(f"        openingDegraded = {degraded}（true=AI不可用走了兜底文案）")
    info(f"        startSession 耗时 {cost:.1f}s（含一次 AI 开场生成）")

    # ---------------- 4. 流式 SSE ----------------
    info("\n=== 4. /chat/stream SSE 流式 ===")
    if not sid:
        red("  [FAIL] 无 sessionId，跳过流式验证")
    else:
        t0 = time.time()
        code, raw = http("POST", f"/api/v1/student/sessions/{sid}/chat/stream",
                         token, body={"message": "您好，请问您哪里不舒服？"},
                         timeout=150, stream=True)
        cost = time.time() - t0
        check("流式接口可达（非 404）", code != 404, f"HTTP {code}, 耗时 {cost:.1f}s")
        if code == 200:
            events = []
            for line in raw.splitlines():
                if line.startswith("event:"):
                    events.append(line[6:].strip())
            msg_cnt = events.count("message")
            check("收到 SSE 事件帧", len(events) > 0,
                  f"事件序列: {events[:12]}{' ...' if len(events) > 12 else ''}")
            check("收到 message 增量（打字机数据源）", msg_cnt > 0,
                  f"message 帧数 = {msg_cnt}")
            if msg_cnt == 0:
                info(f"        原始响应前 400 字符: {raw[:400]}")

    # ---------------- 5. 同步接口未破坏 ----------------
    info("\n=== 5. /chat 同步接口回归（旧路径应仍可用）===")
    if sid:
        code, raw = http("POST", f"/api/v1/student/sessions/{sid}/chat",
                         token, body={"message": "这种情况持续多久了？"},
                         timeout=150)
        ok_sync = code == 200
        detail = f"HTTP {code}"
        if ok_sync:
            try:
                dd = json.loads(raw)
                reply = ((dd.get("data") or {}).get("reply") or "")
                detail += f", reply=「{reply[:60]}」"
            except Exception:  # noqa: BLE001
                pass
        check("同步 /chat 仍可用", ok_sync, detail)

    # ---------------- 结果 ----------------
    info("\n=== 验证结果 ===")
    green(f"  通过: {PASS}")
    if FAIL:
        red(f"  失败: {FAIL}")
    else:
        green("  失败: 0")
    print()
    if FAIL == 0:
        green("全部通过 → 现在可以 flutter run 进问诊室看效果")
    else:
        red("有失败项 → 检查上方 [FAIL] 行")


if __name__ == "__main__":
    main()
