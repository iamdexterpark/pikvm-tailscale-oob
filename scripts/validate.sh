#!/usr/bin/env bash
# validate.sh — local mirror of the CI gate. Exits non-zero on any failure.
# Deliverable-specific logic lives in scripts/gates/<type>.sh (sourced below).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail=0

# --- detect the deliverable + load its gate -------------------------------------------------
GATE=""
if   [ -d manifests ]; then GATE="scripts/gates/manifests.sh"
elif [ -d terraform ]; then GATE="scripts/gates/terraform.sh"
fi
if [ -n "$GATE" ] && [ -f "$GATE" ]; then . "$GATE"; fi

echo "==> 0/3  Preflight (toolchain)"
bash scripts/preflight.sh || { echo "✗ preflight failed — install missing tools above." >&2; exit 1; }

echo "==> 1/3  Doc-sync check (diagrams injected)"
# Robust on a fresh/untracked repo: run the injector, then assert a second pass has no work.
python3 scripts/build_docs.py >/dev/null
if python3 scripts/build_docs.py | grep -qiE 'updated|injected|changed'; then
  echo "✗ Docs out of sync — build_docs.py still had work on a second pass. Commit the result." >&2
  fail=1
else
  echo "✓ Docs in sync (idempotent second pass clean)"
fi

echo "==> 2/4  Deliverable lint/build"
if [ -n "$GATE" ] && declare -f gate_build >/dev/null; then
  gate_build
else
  echo "  (deliverable=none — config/docs repo; no manifest/IaC build. Gating on diagrams + links.)"
fi

echo "==> 3/4  Mermaid edge-syntax gate (the malformed two-dash labeled edge)"
# A labeled edge MUST be -->|"x"| or ---|"x"|. A two-dash --|"x"| is invalid and breaks GitHub render.
if grep -rnE '[^-]--\|' docs/diagrams/src/ 2>/dev/null; then
  echo "✗ Malformed Mermaid edge ('--|') above — use '-->|' or '---|'." >&2
  fail=1
else
  echo "✓ No malformed Mermaid edges"
fi

echo "==> 4/4  Secret-leak scan (value-bearing files only)"
# Use git grep inside a repo; fall back to plain grep for a local-only (non-git) review dir.
SECRET_RE='(BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16}|password\s*[:=]\s*["'\'']?[^"'\'' ]{6,})'
if command -v git >/dev/null && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  hits="$(git grep -nIE "$SECRET_RE" -- . ':!*.md' ':!docs/**' 2>/dev/null || true)"
else
  hits="$(grep -rnIE --exclude='*.md' --exclude-dir=docs --exclude-dir=.git "$SECRET_RE" . 2>/dev/null || true)"
fi
hits="$(printf '%s\n' "$hits" | grep -v 'REPLACE_PASSWORD' | grep -v '^$' || true)"
if [ -n "$hits" ]; then
  printf '%s\n' "$hits" >&2
  echo "✗ Possible secret material in tracked files." >&2
  fail=1
else
  echo "✓ No obvious secret material"
fi

[ "$fail" -eq 0 ] && echo "✅ validate passed" || { echo "❌ validate failed"; exit 1; }
