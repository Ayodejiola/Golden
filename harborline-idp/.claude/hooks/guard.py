#!/usr/bin/env python3
"""Claude Code PreToolUse guard for the Harborline IDP repository.

Reads the hook payload (JSON) from stdin and blocks tool calls that would:
  * mutate live environments (terraform apply, kubectl delete, helm upgrade, ...)
  * read or write secrets, state files, kubeconfigs or private keys
  * write content that looks like a credential or real PII
  * weaken platform security controls (disable policies, privileged pods, ...)

Exit code 2 blocks the call and returns stderr to the model as the reason.
Exit code 0 allows the call. The hook never needs network access.
"""

from __future__ import annotations

import json
import re
import shlex
import sys
from pathlib import PurePosixPath

# Flags may appear between the binary and the verb (e.g. `kubectl -n ns delete`), so match within one pipeline segment.
_SEG = r"[^|;&\n]*?\s"
MUTATING_COMMANDS = [
    r"\bterraform\b" + _SEG + r"(apply|destroy|import|taint|untaint)\b",
    r"\bterraform\b" + _SEG + r"state\s+(rm|mv|push|replace-provider)\b",
    r"\btofu\b" + _SEG + r"(apply|destroy)\b",
    r"\bkubectl\b" + _SEG + r"(apply|create|delete|edit|patch|replace|scale|drain|cordon|exec|cp|label|annotate|set)\b",
    r"\bkubectl\b" + _SEG + r"rollout\s+(restart|undo)\b",
    r"\bhelm\b" + _SEG + r"(install|upgrade|uninstall|rollback)\b",
    r"\bargocd\b" + _SEG + r"(sync|delete|set|rollback|terminate-op)\b",
    r"\baz\b" + _SEG + r"(create|delete|update|purge|assign|reset|regenerate|rotate|import|restart|stop|failover)\b",
    r"\baz\b" + _SEG + r"(?<!account )set\b",
    r"\bgit\s+push\b.*(--force|-f\b|--force-with-lease)",
    r"\bgit\s+push\s+\S+\s+(main|master)\b",
    r"\brm\s+-rf\s+(/|~|\$HOME|\.\s*$)",
    r"\b(curl|wget)\b.*\|\s*(ba|z)?sh\b",
]

SECRET_PATHS = [
    r"(^|/)\.env(\..*)?$",
    r"\.tfstate(\.backup)?$",
    r"(^|/)kubeconfig[^/]*$",
    r"(^|/)\.kube/",
    r"(^|/)\.azure/",
    r"\.(pem|key|pfx|p12|jks)$",
    r"(^|/)id_(rsa|ed25519|ecdsa)$",
    r"(^|/)\.terraform/",
]

SECRET_CONTENT = [
    (r"-----BEGIN (RSA |EC |OPENSSH |)PRIVATE KEY-----", "private key"),
    (r"AccountKey=[A-Za-z0-9+/=]{40,}", "Azure storage account key"),
    (r"SharedAccessKey=[A-Za-z0-9+/=]{30,}", "Service Bus / Event Hub SAS key"),
    (r"InstrumentationKey=[0-9a-f]{8}-(?!0000)[0-9a-f]{4}-", "Application Insights key"),
    (r"\bgh[pousr]_[A-Za-z0-9]{36,}\b", "GitHub token"),
    (r"\bsk-ant-[A-Za-z0-9\-_]{20,}\b", "Anthropic API key"),
    (r"(?i)\bclient_secret\s*[:=]\s*['\"][^'\"$]{16,}['\"]", "client secret literal"),
    (r"(?i)password\s*[:=]\s*['\"](?!\$\{|<|changeme|example)[^'\"]{8,}['\"]", "password literal"),
]

PII_CONTENT = [
    (r"\b\d{3}-\d{3}-\d{3}\b(?=.*(?i:sin|social))", "Canadian SIN"),
    (r"\b\d{3}-\d{2}-\d{4}\b", "US SSN-shaped number"),
    (r"\b(?:4\d{3}|5[1-5]\d{2})[ -]?\d{4}[ -]?\d{4}[ -]?\d{4}\b", "payment card number"),
]

CONTROL_WEAKENING = [
    (r"validationFailureAction:\s*(Audit|audit)", "switching Kyverno policy to Audit"),
    (r"privileged:\s*true", "privileged container"),
    (r"allowPrivilegeEscalation:\s*true", "privilege escalation"),
    (r"runAsNonRoot:\s*false", "running as root"),
    (r"readOnlyRootFilesystem:\s*false", "writable root filesystem"),
    (r"hostNetwork:\s*true", "hostNetwork"),
    (r"public_network_access_enabled\s*=\s*true", "public network access"),
    (r"local_auth_enabled\s*=\s*true", "local (key) auth"),
    (r"local_account_disabled\s*=\s*false", "AKS local accounts"),
    (r"firewall_mode\s*=\s*\"Detection\"", "WAF detection-only mode"),
    (r"enforcement_mode\s*=\s*\"DoNotEnforce\"", "Azure Policy not enforced"),
]

# Paths where weakening patterns are legitimately present (tests, policy fixtures, docs about the guard itself).
CONTROL_ALLOWLIST = [
    r"^platform/policies/kyverno/tests/",
    r"^docs/",
    r"^\.claude/hooks/",
    r"/tests?/",
]


def block(reason: str) -> None:
    print(
        f"BLOCKED by Harborline guardrail: {reason}. "
        "See CLAUDE.md and docs/ai/guardrails.md. If this is legitimate, ask a human to do it via a PR/pipeline.",
        file=sys.stderr,
    )
    sys.exit(2)


def rel(path: str, root: str) -> str:
    p = PurePosixPath(path)
    try:
        return str(p.relative_to(root)) if root and p.is_absolute() else str(p)
    except ValueError:
        return str(p)


def check_bash(cmd: str) -> None:
    for pat in MUTATING_COMMANDS:
        if re.search(pat, cmd):
            block(f"command mutates a live environment or history (`{pat}`)")
    try:
        tokens = shlex.split(cmd, comments=True)
    except ValueError:
        tokens = cmd.split()
    for tok in tokens:
        for pat in SECRET_PATHS:
            if re.search(pat, tok):
                block(f"command touches a secret-bearing path ({tok})")
    if re.search(r"(^|[;&|]\s*)(printenv|env)\s*($|[;&|])", cmd):
        block("dumping the environment can expose credentials")


def check_read(path: str) -> None:
    for pat in SECRET_PATHS:
        if re.search(pat, path):
            block(f"reading secret-bearing path {path}")


def check_write(path: str, content: str) -> None:
    check_read(path)
    for pat, label in SECRET_CONTENT:
        if re.search(pat, content):
            block(f"content contains what looks like a {label}")
    for pat, label in PII_CONTENT:
        if re.search(pat, content) and not re.search(r"(^|/)(tests?|fixtures)/", path):
            block(f"content contains what looks like a {label}; use synthetic fixtures")
    if not any(re.search(a, path) for a in CONTROL_ALLOWLIST):
        for pat, label in CONTROL_WEAKENING:
            if re.search(pat, content):
                block(f"change weakens a platform control ({label}); raise an exception request instead")


def main() -> None:
    mode = sys.argv[1] if len(sys.argv) > 1 else "bash"
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)
    tool_input = payload.get("tool_input", {}) or {}
    root = payload.get("cwd", "")
    if mode == "bash":
        check_bash(tool_input.get("command", ""))
    elif mode == "read":
        check_read(rel(tool_input.get("file_path", ""), root))
    elif mode == "write":
        path = rel(tool_input.get("file_path", ""), root)
        content = tool_input.get("content") or tool_input.get("new_string") or ""
        for edit in tool_input.get("edits", []) or []:
            content += "\n" + edit.get("new_string", "")
        check_write(path, content)
    sys.exit(0)


if __name__ == "__main__":
    main()
