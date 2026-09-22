#!/usr/bin/env python3
"""Offline app-server fixture for release execution checks; never reads user data."""

import json
import sys
import time


def main():
    if sys.argv[1:] == ["--version"]:
        print("codex-cli 0.0.0")
        return
    if len(sys.argv) < 2 or sys.argv[1] != "app-server":
        raise SystemExit(2)

    for line in sys.stdin:
        request = json.loads(line)
        if "id" not in request:
            continue
        method = request.get("method")
        if method == "initialize":
            result = {"userAgent": "release-fixture"}
        elif method == "account/rateLimits/read":
            now = int(time.time())
            bucket = {
                "limitId": "codex",
                "limitName": "Codex",
                "primary": {"usedPercent": 22, "windowDurationMins": 300, "resetsAt": now + 3600},
                "secondary": {"usedPercent": 44, "windowDurationMins": 10080, "resetsAt": now + 604800},
            }
            result = {"rateLimits": bucket, "rateLimitsByLimitId": {"codex": bucket}}
        elif method == "account/usage/read":
            result = {"dailyUsageBuckets": [], "summary": {}}
        else:
            print(json.dumps({"id": request["id"], "error": {"code": -32601, "message": "Unsupported fixture method"}}), flush=True)
            continue
        print(json.dumps({"id": request["id"], "result": result}), flush=True)


if __name__ == "__main__":
    main()
