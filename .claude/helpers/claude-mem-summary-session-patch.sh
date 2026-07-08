#!/usr/bin/env bash
set -euo pipefail

# Watch summarize/session-complete TIMEOUT rates alongside store-rate post-merge;
# sustained worker timeouts would cap effective memory storage even with this patch.

helper_path="${BASH_SOURCE[0]}"
cache_root="${CLAUDE_MEM_CACHE_ROOT:-$HOME/.claude/plugins/cache/thedotmack/claude-mem}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/claude-mem-summary-session-patch"

newest_cache_dir() {
  local newest=""
  local dir

  if [[ -d "$cache_root" ]]; then
    for dir in "$cache_root"/*; do
      [[ -d "$dir" ]] || continue
      if [[ -z "$newest" || "$dir" -nt "$newest" ]]; then
        newest="$dir"
      fi
    done
  fi

  [[ -n "$newest" ]] && printf '%s\n' "$newest"
}

worker_file() {
  local root
  root="$(newest_cache_dir || true)"
  [[ -n "$root" ]] || return 1
  printf '%s/scripts/worker-service.cjs\n' "${root%/}"
}

count_occurrences() {
  local needle="$1"
  local file="$2"
  { grep -Fo "$needle" "$file" || true; } | wc -l | tr -d ' '
}

patch_once() {
  local worker tmp_file \
    anchor_clear replacement_clear clear_count clear_patched_count \
    anchor_routing replacement_routing routing_count routing_patched_count \
    anchor_resume replacement_resume resume_count resume_patched_count \
    anchor_capture replacement_capture capture_count capture_patched_count \
    anchor_complete replacement_complete complete_count complete_patched_count
  worker="${1:-$(worker_file)}"
  [[ -f "$worker" ]] || return 0

  anchor_clear='applyTierRouting(r){let n=ge.loadFromFile(lt);'
  replacement_clear='applyTierRouting(r){r.forceFreshSummary=!1;let n=ge.loadFromFile(lt);'
  anchor_routing='c&&(r.modelOverride=c,_.debug("SESSION","Tier routing: summary model",{sessionId:r.sessionDbId,model:c}))'
  replacement_routing='c&&(r.modelOverride=c,r.forceFreshSummary=!0,_.debug("SESSION","Tier routing: summary model",{sessionId:r.sessionDbId,model:c,forceFreshSummary:!0}))'
  anchor_resume='u=c&&e.lastPromptNumber>1&&!e.forceInit;'
  replacement_resume='u=c&&e.lastPromptNumber>1&&!e.forceInit&&!e.forceFreshSummary;'
  anchor_capture='if(g.session_id&&g.session_id!==e.memorySessionId){'
  replacement_capture='if(g.session_id&&g.session_id!==e.memorySessionId&&!e.forceFreshSummary){'
  anchor_complete='ct("/api/sessions/complete",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({contentSessionId:r,platformSource:n})})'
  replacement_complete='ct("/api/sessions/complete",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({contentSessionId:r,platformSource:n}),timeoutMs:15e3})'

  clear_count="$(count_occurrences "$anchor_clear" "$worker")"
  routing_count="$(count_occurrences "$anchor_routing" "$worker")"
  resume_count="$(count_occurrences "$anchor_resume" "$worker")"
  capture_count="$(count_occurrences "$anchor_capture" "$worker")"
  complete_count="$(count_occurrences "$anchor_complete" "$worker")"
  clear_patched_count="$(count_occurrences "$replacement_clear" "$worker")"
  routing_patched_count="$(count_occurrences "$replacement_routing" "$worker")"
  resume_patched_count="$(count_occurrences "$replacement_resume" "$worker")"
  capture_patched_count="$(count_occurrences "$replacement_capture" "$worker")"
  complete_patched_count="$(count_occurrences "$replacement_complete" "$worker")"

  if [[ $((clear_count + clear_patched_count)) != 1 \
    || $((routing_count + routing_patched_count)) != 1 \
    || $((resume_count + resume_patched_count)) != 1 \
    || $((capture_count + capture_patched_count)) != 1 \
    || $((complete_count + complete_patched_count)) != 1 ]]; then
    printf 'claude-mem summary patch refused for %s: clear=%s/%s routing=%s/%s resume=%s/%s capture=%s/%s complete=%s/%s\n' \
      "$worker" \
      "$clear_count" "$clear_patched_count" \
      "$routing_count" "$routing_patched_count" \
      "$resume_count" "$resume_patched_count" \
      "$capture_count" "$capture_patched_count" \
      "$complete_count" "$complete_patched_count" >&2
    return 1
  fi

  if [[ "$clear_patched_count" == "1" \
    && "$routing_patched_count" == "1" \
    && "$resume_patched_count" == "1" \
    && "$capture_patched_count" == "1" \
    && "$complete_patched_count" == "1" ]]; then
    return 10
  fi

  tmp_file="$(mktemp --suffix=.cjs "${worker}.XXXXXX")"
  trap 'rm -f "$tmp_file"' RETURN
  python3 - "$worker" \
    "$anchor_clear" "$replacement_clear" \
    "$anchor_routing" "$replacement_routing" \
    "$anchor_resume" "$replacement_resume" \
    "$anchor_capture" "$replacement_capture" \
    "$anchor_complete" "$replacement_complete" > "$tmp_file" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
replacements = [
    (sys.argv[2], sys.argv[3]),
    (sys.argv[4], sys.argv[5]),
    (sys.argv[6], sys.argv[7]),
    (sys.argv[8], sys.argv[9]),
    (sys.argv[10], sys.argv[11]),
]
text = path.read_text()
patched = text
for anchor, replacement in replacements:
    anchor_count = patched.count(anchor)
    replacement_count = patched.count(replacement)
    if anchor_count == 1 and replacement_count == 0:
        patched = patched.replace(anchor, replacement, 1)
    elif anchor_count == 0 and replacement_count == 1:
        continue
    else:
        raise SystemExit(1)
for _anchor, replacement in replacements:
    if patched.count(replacement) != 1:
        raise SystemExit(1)
sys.stdout.write(patched)
PY

  # Deliberate: this minified bundle uses import.meta.url, so CommonJS
  # `node --check *.cjs` false-fails; the ESM parse goal is required here.
  node --input-type=module --check < "$tmp_file" >/dev/null
  mv "$tmp_file" "$worker"
  trap - RETURN
}

monitor_patch() {
  local attempt already_patched_count rc
  mkdir -p "$state_dir"

  exec 9>"$state_dir/monitor.lock"
  flock -n 9 || exit 0

  already_patched_count=0
  for ((attempt = 0; attempt < 600; attempt++)); do
    set +e
    patch_once >/dev/null 2>&1
    rc=$?
    set -e
    if [[ "$rc" == "10" ]]; then
      already_patched_count=$((already_patched_count + 1))
      [[ "$already_patched_count" -ge 2 ]] && break
    else
      already_patched_count=0
    fi
    sleep 0.5
  done
}

install_patch() {
  patch_once >/dev/null 2>&1 || true
  nohup bash "$helper_path" monitor >/dev/null 2>&1 &
  printf '%s\n' '{"continue":true,"suppressOutput":true}'
}

case "${1:-install}" in
  install|patch)
    install_patch
    ;;
  patch-once)
    patch_once "${2:-}" || {
      rc=$?
      [[ "$rc" == "10" ]] || exit "$rc"
    }
    ;;
  monitor)
    monitor_patch
    ;;
  *)
    printf 'usage: %s [install|patch|patch-once [worker-file]|monitor]\n' "$0" >&2
    exit 64
    ;;
esac
