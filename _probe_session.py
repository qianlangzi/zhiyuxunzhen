import os, urllib.request, json

tok = os.environ.get("AI_INTERNAL_TOKEN", "dev-internal-token")
H = {"X-Internal-Token": tok}

# 1) context with studentId
url = "http://backend:8080/api/internal/session/95/context?studentId=6"
req = urllib.request.Request(url, headers=H)
try:
    r = urllib.request.urlopen(req, timeout=8)
    d = json.loads(r.read().decode())
    data = d.get("data") or {}
    msgs = data.get("messages")
    print("CTX_OK code=", d.get("code"), "keys=", list(data.keys())[:15])
    print("msgCount=", len(msgs) if isinstance(msgs, list) else msgs)
    if isinstance(msgs, list) and msgs:
        print("firstMsg=", json.dumps(msgs[0], ensure_ascii=False)[:200])
        print("lastMsg=", json.dumps(msgs[-1], ensure_ascii=False)[:200])
    print("title=", data.get("title"))
except urllib.error.HTTPError as e:
    print("CTX_HTTPERR", e.code, e.read().decode()[:500])
except Exception as e:
    print("CTX_ERR", type(e).__name__, e)

# 2) replay evaluate_and_archive
url2 = "http://localhost:8000/session/evaluate_and_archive"
body = json.dumps({"sessionId": 95, "studentId": 6}).encode()
req2 = urllib.request.Request(url2, data=body, headers={**H, "Content-Type": "application/json"})
try:
    r2 = urllib.request.urlopen(req2, timeout=120)
    print("EVAL_HTTP", r2.status, r2.read().decode()[:800])
except urllib.error.HTTPError as e:
    print("EVAL_HTTPERR", e.code, e.read().decode()[:800])
except Exception as e:
    print("EVAL_ERR", type(e).__name__, e)
