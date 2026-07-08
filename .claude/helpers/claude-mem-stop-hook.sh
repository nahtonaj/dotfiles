#!/usr/bin/env bash
set -euo pipefail

helper_path="${BASH_SOURCE[0]}"
helper_command="bash \"\$HOME/.claude/helpers/claude-mem-stop-hook.sh\" summarize"
cache_root="${CLAUDE_MEM_CACHE_ROOT:-$HOME/.claude/plugins/cache/thedotmack/claude-mem}"
marketplace_root="${CLAUDE_MEM_MARKETPLACE_ROOT:-$HOME/.claude/plugins/marketplaces/thedotmack/plugin}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/claude-mem-stop-hook"

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
  if jq --arg command "$helper_command" '
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
  ' "$hooks_file" > "$tmp_file"; then
    mv "$tmp_file" "$hooks_file"
  else
    rm -f "$tmp_file"
    return 1
  fi
}

monitor_patch() {
  local attempt
  mkdir -p "$state_dir"

  exec 9>"$state_dir/monitor.lock"
  flock -n 9 || exit 0

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
  local input_file log_dir log_file root

  printf '%s\n' '{"continue":true,"suppressOutput":true}'

  log_dir="$HOME/.claude-mem/logs"
  log_file="$log_dir/claude-mem-stop-background.log"

  input_file="$(mktemp "${TMPDIR:-/tmp}/claude-mem-stop.XXXXXX")" || return 0

  cat > "$input_file"

  root="$(plugin_root || true)"

  if [[ -z "$root" ]]; then
    rm -f "$input_file"
    return 0
  fi

  mkdir -p "$log_dir" || {
    rm -f "$input_file"
    return 0
  }

  if command -v setsid >/dev/null 2>&1; then
    # shellcheck disable=SC2016
    setsid bash -c '
      trap "rm -f \"$1\"" EXIT
      trap "" TERM HUP INT
      node "$2/scripts/bun-runner.js" "$2/scripts/worker-service.cjs" hook claude-code summarize < "$1" >> "$3" 2>&1
    ' bash "$input_file" "$root" "$log_file" >/dev/null 2>&1 &
  else
    # shellcheck disable=SC2016
    nohup bash -c '
      trap "rm -f \"$1\"" EXIT
      trap "" TERM HUP INT
      node "$2/scripts/bun-runner.js" "$2/scripts/worker-service.cjs" hook claude-code summarize < "$1" >> "$3" 2>&1
    ' bash "$input_file" "$root" "$log_file" >/dev/null 2>&1 &
  fi
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
