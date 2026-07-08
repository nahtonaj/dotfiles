#!/usr/bin/env bash
set -euo pipefail

helper_path="${BASH_SOURCE[0]}"
helper_command="bash \"\$HOME/.claude/helpers/claude-mem-stop-hook.sh\" summarize"
cache_root="${CLAUDE_MEM_CACHE_ROOT:-$HOME/.claude/plugins/cache/thedotmack/claude-mem}"
marketplace_root="${CLAUDE_MEM_MARKETPLACE_ROOT:-$HOME/.claude/plugins/marketplaces/thedotmack/plugin}"

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

plugin_root() {
  local root="${CLAUDE_PLUGIN_ROOT:-}"

  if [[ -z "$root" ]]; then
    root="$(newest_cache_dir || true)"
  fi

  if [[ -z "$root" && -d "$marketplace_root" ]]; then
    root="$marketplace_root"
  fi

  [[ -n "$root" ]] && printf '%s\n' "${root%/}"
}

hooks_json() {
  local root
  root="$(newest_cache_dir || true)"
  [[ -n "$root" ]] || return 1
  printf '%s/hooks/hooks.json\n' "${root%/}"
}

patch_once() {
  local hooks_file tmp_file
  hooks_file="$(hooks_json)"
  [[ -f "$hooks_file" ]] || return 0

  tmp_file="$(mktemp "${hooks_file}.XXXXXX")"
  jq --arg command "$helper_command" '
    .hooks.Stop |= (
      map(
        .hooks |= map(
          if .type == "command"
            and (.command | type == "string")
            and ((.command | contains("hook claude-code summarize")) or .command == $command)
          then .command = $command | .timeout = 5
          else .
          end
        )
      )
    )
  ' "$hooks_file" > "$tmp_file"
  mv "$tmp_file" "$hooks_file"
}

monitor_patch() {
  local attempt
  for ((attempt = 0; attempt < 600; attempt++)); do
    patch_once >/dev/null 2>&1 || true
    sleep 0.5
  done
}

install_patch() {
  patch_once >/dev/null 2>&1 || true
  nohup bash "$helper_path" monitor >/dev/null 2>&1 &
  printf '%s\n' '{"continue":true,"suppressOutput":true}'
}

run_summarize_background() {
  local root input_file log_dir log_file shell_path
  root="$(plugin_root || true)"
  log_dir="$HOME/.claude-mem/logs"
  log_file="$log_dir/claude-mem-stop-background.log"
  input_file="$(mktemp "${TMPDIR:-/tmp}/claude-mem-stop.XXXXXX")"

  cat > "$input_file"

  if [[ -z "$root" ]]; then
    rm -f "$input_file"
    printf '%s\n' '{"continue":true,"suppressOutput":true}'
    return 0
  fi

  mkdir -p "$log_dir"
  shell_path="${SHELL:-/bin/sh}"

  (
    trap '' HUP
    login_path="$($shell_path -lc "printf %s \"\$PATH\"" 2>/dev/null)"
    export PATH="$login_path:$PATH"
    node "$root/scripts/bun-runner.js" "$root/scripts/worker-service.cjs" hook claude-code summarize < "$input_file" >> "$log_file" 2>&1
    rm -f "$input_file"
  ) >/dev/null 2>&1 &

  printf '%s\n' '{"continue":true,"suppressOutput":true}'
}

case "${1:-install}" in
  install|patch)
    install_patch
    ;;
  patch-once)
    patch_once
    ;;
  monitor)
    monitor_patch
    ;;
  summarize)
    run_summarize_background
    ;;
  *)
    printf 'usage: %s [install|patch|patch-once|monitor|summarize]\n' "$0" >&2
    exit 64
    ;;
esac
