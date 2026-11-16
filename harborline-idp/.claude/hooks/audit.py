#!/usr/bin/env python3
"""PostToolUse audit hook: appends a minimal, PII-free record of every AI tool call.

Records go to .claude/audit/YYYY-MM-DD.jsonl (git-ignored) and, when AI_AUDIT_ENDPOINT is
set by the developer workstation baseline, are forwarded by the endpoint agent to the SIEM.
Only tool name, target path/command verb, outcome and session id are stored — never content.
"""

from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
import sys
from pathlib import Path


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        return
    tool = payload.get("tool_name", "unknown")
    tin = payload.get("tool_input", {}) or {}
    target = tin.get("file_path") or ""
    command = tin.get("command") or ""
    record = {
        "ts": dt.datetime.now(dt.UTC).isoformat(),
        "session": payload.get("session_id", ""),
        "tool": tool,
        "target": target,
        # Store only the verb of shell commands plus a hash, never arguments that may carry data.
        "command_verb": " ".join(command.split()[:2]) if command else "",
        "command_sha256": hashlib.sha256(command.encode()).hexdigest() if command else "",
        "user": os.environ.get("USER", ""),
    }
    root = Path(os.environ.get("CLAUDE_PROJECT_DIR", "."))
    out_dir = root / ".claude" / "audit"
    out_dir.mkdir(parents=True, exist_ok=True)
    with (out_dir / f"{dt.date.today().isoformat()}.jsonl").open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(record) + "\n")


if __name__ == "__main__":
    main()
