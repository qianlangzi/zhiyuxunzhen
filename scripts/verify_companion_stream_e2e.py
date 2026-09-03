#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""AI 学伴流式端到端快验：登录 → /companion/stream SSE → 统计 message 帧。

用法：python scripts/verify_companion_stream_e2e.py
"""
import json
import sys
import urllib.error
import urllib.request

BASE = "http://localhost:18080"


def main():
    # 1. 登录
    req = urllib.request.Request(
        BASE + "/api/v1/auth/login",
        data=json.dumps({"username": "student01", "password": "123456"}).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        d = json.loads(r.read().decode())
    token = d["data"]["token"]
    print(f"[1] 登录 OK userId={d['data'].get('userId')}")

    # 2. 学伴流式
    req = urllib.request.Request(
        BASE + "/api/v1/student/companion/stream",
        data=json.dumps({"message": "我最近内科总是学不明白，怎么办？", "history": []}).encode(),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {token}",
            "Accept": "text/event-stream",
        },
        method="POST",
    )
    events = []
    msg_deltas = 0
    try:
        with urllib.request.urlopen(req, timeout=150) as r:
            event = None
            for raw in r:
                line = raw.decode("utf-8", errors="replace").rstrip("\n").rstrip("\r")
                if line.startswith("event:"):
                    event = line[6:].strip()
                    events.append(event)
                elif line.startswith("data:") and event == "message":
                    try:
                        payload = json.loads(line[5:].strip())
                        if payload.get("delta"):
                            msg_deltas += 1
                    except json.JSONDecodeError:
                        pass
    except urllib.error.HTTPError as e:
        print(f"[FAIL] HTTP {e.code}: {e.read().decode()[:300]}")
        sys.exit(1)

    print(f"[2] SSE 事件序列前 12: {events[:12]}")
    print(f"[3] message 增量帧数 = {msg_deltas}")
    if msg_deltas > 0:
        print("[PASS] 学伴真流式打字机数据源正常")
    else:
        print("[FAIL] 未收到 message 增量（流式仍不通）")
        sys.exit(1)


if __name__ == "__main__":
    main()
