#!/bin/bash
# DDD Progress Tracker — Generic Project Auto-Discovery
# Discovers bounded contexts in any codebase and tracks DDD progress

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
METRICS_DIR="$PROJECT_ROOT/.claude-flow/metrics"
DDD_FILE="$METRICS_DIR/ddd-progress.json"
V3_PROGRESS="$METRICS_DIR/v3-progress.json"
LAST_RUN_FILE="$METRICS_DIR/.ddd-last-run"

mkdir -p "$METRICS_DIR"

EXCLUDE_DIRS="node_modules|\.git|dist|build|target|\.claude-flow|\.claude|__pycache__|\.mypy_cache|\.tox|\.venv|venv|\.swarm|\.next|coverage"

should_run() {
  if [ ! -f "$LAST_RUN_FILE" ]; then return 0; fi
  local last_run
  last_run=$(cat "$LAST_RUN_FILE" 2>/dev/null || echo "0")
  local now
  now=$(date +%s)
  [ $((now - last_run)) -ge 600 ]
}

discover_domains() {
  local domains=()

  if [ -f "$PROJECT_ROOT/flake.nix" ] || compgen -G "$PROJECT_ROOT/*.nix" >/dev/null 2>&1; then
    # Nix project: each .nix module file = one domain
    # Path is configs/<name>/ if it exists, else the .nix file itself
    if [ -d "$PROJECT_ROOT/nix/modules" ]; then
      for f in "$PROJECT_ROOT/nix/modules"/*.nix; do
        [ -f "$f" ] || continue
        local name
        name=$(basename "$f" .nix)
        if [ -d "$PROJECT_ROOT/configs/$name" ]; then
          domains+=("$name:$PROJECT_ROOT/configs/$name")
        else
          domains+=("$name:$f")
        fi
      done
    fi
    if [ -d "$PROJECT_ROOT/nix/modules-darwin" ]; then
      for f in "$PROJECT_ROOT/nix/modules-darwin"/*.nix; do
        [ -f "$f" ] || continue
        local name
        name=$(basename "$f" .nix)
        if [ -d "$PROJECT_ROOT/configs/$name" ]; then
          domains+=("$name:$PROJECT_ROOT/configs/$name")
        else
          domains+=("$name:$f")
        fi
      done
    fi
  elif [ -f "$PROJECT_ROOT/package.json" ]; then
    for dir in src lib packages; do
      [ -d "$PROJECT_ROOT/$dir" ] || continue
      for d in "$PROJECT_ROOT/$dir"/*/; do
        [ -d "$d" ] || continue
        local name
        name=$(basename "$d")
        echo "$name" | grep -qE "^($EXCLUDE_DIRS)$" && continue
        local count
        count=$(find "$d" -maxdepth 2 -type f \( -name "*.ts" -o -name "*.js" -o -name "*.tsx" -o -name "*.jsx" \) 2>/dev/null | wc -l)
        [ "$count" -ge 3 ] && domains+=("$name:$d")
      done
    done
  elif [ -f "$PROJECT_ROOT/Cargo.toml" ]; then
    for dir in crates src; do
      [ -d "$PROJECT_ROOT/$dir" ] || continue
      for d in "$PROJECT_ROOT/$dir"/*/; do
        [ -d "$d" ] || continue
        local name
        name=$(basename "$d")
        echo "$name" | grep -qE "^($EXCLUDE_DIRS)$" && continue
        domains+=("$name:$d")
      done
    done
  elif [ -f "$PROJECT_ROOT/go.mod" ]; then
    for d in "$PROJECT_ROOT"/*/; do
      [ -d "$d" ] || continue
      local name
      name=$(basename "$d")
      echo "$name" | grep -qE "^($EXCLUDE_DIRS)$" && continue
      local count
      count=$(find "$d" -maxdepth 2 -name "*.go" 2>/dev/null | wc -l)
      [ "$count" -ge 1 ] && domains+=("$name:$d")
    done
  elif [ -f "$PROJECT_ROOT/pyproject.toml" ] || [ -f "$PROJECT_ROOT/setup.py" ]; then
    for d in "$PROJECT_ROOT"/*/; do
      [ -d "$d" ] || continue
      local name
      name=$(basename "$d")
      echo "$name" | grep -qE "^($EXCLUDE_DIRS)$" && continue
      [ -f "$d/__init__.py" ] && domains+=("$name:$d")
    done
  fi

  # Fallback: scan top-level dirs with 3+ source files
  if [ ${#domains[@]} -eq 0 ]; then
    for d in "$PROJECT_ROOT"/*/; do
      [ -d "$d" ] || continue
      local name
      name=$(basename "$d")
      echo "$name" | grep -qE "^($EXCLUDE_DIRS)$" && continue
      local count
      count=$(find "$d" -maxdepth 3 -type f \( -name "*.nix" -o -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" -o -name "*.rs" -o -name "*.sh" -o -name "*.lua" \) 2>/dev/null | wc -l)
      [ "$count" -ge 3 ] && domains+=("$name:$d")
    done
  fi

  if [ ${#domains[@]} -gt 0 ]; then
    printf '%s\n' "${domains[@]}"
  fi
}

# Score a domain that's a single file (e.g., a Nix module .nix file)
check_file_domain() {
  local domain_name="$1"
  local domain_file="$2"
  local score=0

  # File exists = clear boundary (25 pts)
  [ -f "$domain_file" ] && score=$((score + 25))

  # File is self-contained entry point (20 pts)
  score=$((score + 20))

  # Low coupling: count references to other modules in the file (20 pts max)
  local refs
  refs=$(grep -cE "import|require|\.\/|\.\./" "$domain_file" 2>/dev/null || true)
  refs=$(echo "${refs:-0}" | tr -d '[:space:]')
  local coupling_score=$((20 - 2 * refs))
  [ "$coupling_score" -lt 0 ] && coupling_score=0
  score=$((score + coupling_score))

  # No tests for single-file domain (0 pts)
  # No README (0 pts)

  # Consistent naming (10 pts — single file is inherently consistent)
  score=$((score + 10))

  echo "$score"
}

# Score a domain that's a directory
check_dir_domain() {
  local domain_name="$1"
  local domain_path="$2"
  local score=0

  # Has clear boundary (own directory with 3+ files) — 25 pts
  local file_count
  file_count=$(find "$domain_path" -maxdepth 3 -type f 2>/dev/null | wc -l)
  file_count=$(echo "${file_count:-0}" | tr -d '[:space:]')
  [ "$file_count" -ge 3 ] && score=$((score + 25))

  # Has own entry point — 20 pts
  local has_entry=0
  for entry in index main mod default lib; do
    if compgen -G "$domain_path/${entry}.*" >/dev/null 2>&1; then
      has_entry=1
      break
    fi
  done
  [ -f "$domain_path/$domain_name.nix" ] && has_entry=1
  [ "$has_entry" -eq 1 ] && score=$((score + 20))

  # Low coupling — 20 pts (simple: count files with import-like keywords, cap at 10)
  local cross_refs
  cross_refs=$(grep -rlE "import|require" "$domain_path" 2>/dev/null | head -10 | wc -l || true)
  cross_refs=$(echo "${cross_refs:-0}" | tr -d '[:space:]')
  local coupling_score=$((20 - 2 * cross_refs))
  [ "$coupling_score" -lt 0 ] && coupling_score=0
  score=$((score + coupling_score))

  # Has tests — 15 pts
  local test_count
  test_count=$(find "$domain_path" -maxdepth 3 -type f \( -name "*test*" -o -name "*spec*" \) 2>/dev/null | wc -l)
  test_count=$(echo "${test_count:-0}" | tr -d '[:space:]')
  if [ -d "$domain_path/tests" ] || [ -d "$domain_path/test" ]; then
    test_count=$((test_count + 1))
  fi
  [ "$test_count" -gt 0 ] && score=$((score + 15))

  # Has README or docs — 10 pts
  if [ -f "$domain_path/README.md" ] || [ -f "$domain_path/README" ] || [ -d "$domain_path/docs" ]; then
    score=$((score + 10))
  fi

  # Consistent naming — 10 pts
  local total_files
  total_files=$(find "$domain_path" -maxdepth 2 -type f 2>/dev/null | wc -l)
  total_files=$(echo "${total_files:-0}" | tr -d '[:space:]')
  if [ "$total_files" -gt 0 ]; then
    local top_ext_count
    top_ext_count=$(find "$domain_path" -maxdepth 2 -type f 2>/dev/null | grep -oE '\.[^./]+$' | sort | uniq -c | sort -rn | head -1 | awk '{print $1}')
    top_ext_count=$(echo "${top_ext_count:-0}" | tr -d '[:space:]')
    if [ "${top_ext_count:-0}" -gt 0 ]; then
      local ratio=$((top_ext_count * 100 / total_files))
      [ "$ratio" -ge 50 ] && score=$((score + 10))
    fi
  fi

  echo "$score"
}

check_domain() {
  local domain_name="$1"
  local domain_path="$2"

  if [ -f "$domain_path" ]; then
    check_file_domain "$domain_name" "$domain_path"
  elif [ -d "$domain_path" ]; then
    check_dir_domain "$domain_name" "$domain_path"
  else
    echo "0"
  fi
}

count_entities() {
  local path="$1"
  if [ -f "$path" ]; then
    echo "1"
  elif [ -d "$path" ]; then
    local n
    n=$(find "$path" -maxdepth 3 -type f 2>/dev/null | wc -l)
    echo "$(echo "${n:-0}" | tr -d '[:space:]')"
  else
    echo "0"
  fi
}

track_ddd() {
  echo "[$(date +%H:%M:%S)] Tracking DDD progress..."

  local domain_list
  domain_list=$(discover_domains)

  if [ -z "$domain_list" ]; then
    echo "[$(date +%H:%M:%S)] No domains discovered in $PROJECT_ROOT"
    cat > "$DDD_FILE" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "progress": 0,
  "domains": {},
  "completed": 0,
  "total": 0,
  "artifacts": {
    "entities": 0
  }
}
EOF
    date +%s > "$LAST_RUN_FILE"
    return
  fi

  local total_score=0
  local domain_scores=""
  local completed_domains=0
  local domain_count=0
  local total_entities=0

  while IFS=: read -r name path; do
    [ -z "$name" ] && continue
    domain_count=$((domain_count + 1))

    local score
    score=$(check_domain "$name" "$path")
    score=$(echo "${score:-0}" | tr -d '[:space:]')
    [ -z "$score" ] && score=0

    total_score=$((total_score + score))

    local entities
    entities=$(count_entities "$path")
    entities=$(echo "${entities:-0}" | tr -d '[:space:]')
    total_entities=$((total_entities + entities))

    [ -n "$domain_scores" ] && domain_scores="$domain_scores, "
    domain_scores="$domain_scores\"$name\": $score"

    [ "$score" -ge 50 ] && completed_domains=$((completed_domains + 1))
  done <<< "$domain_list"

  local max_total=$((domain_count * 100))
  local progress=0
  [ "$max_total" -gt 0 ] && progress=$((total_score * 100 / max_total))

  cat > "$DDD_FILE" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "progress": $progress,
  "domains": {
    $domain_scores
  },
  "completed": $completed_domains,
  "total": $domain_count,
  "artifacts": {
    "entities": $total_entities
  }
}
EOF

  if [ -f "$V3_PROGRESS" ] && command -v jq &>/dev/null; then
    jq --argjson progress "$progress" --argjson completed "$completed_domains" \
      '.ddd.progress = $progress | .domains.completed = $completed' \
      "$V3_PROGRESS" > "$V3_PROGRESS.tmp" && mv "$V3_PROGRESS.tmp" "$V3_PROGRESS"
  fi

  echo "[$(date +%H:%M:%S)] DDD: ${progress}% | Domains: $completed_domains/$domain_count | Entities: $total_entities"

  date +%s > "$LAST_RUN_FILE"
}

case "${1:-check}" in
  "run"|"track") track_ddd ;;
  "check") should_run && track_ddd || echo "[$(date +%H:%M:%S)] Skipping (throttled)" ;;
  "force") rm -f "$LAST_RUN_FILE"; track_ddd ;;
  "status")
    if [ -f "$DDD_FILE" ]; then
      jq -r '"Progress: \(.progress)% | Domains: \(.completed)/\(.total) | Entities: \(.artifacts.entities)"' "$DDD_FILE"
    else
      echo "No DDD data available"
    fi
    ;;
  "discover") discover_domains ;;
  *) echo "Usage: $0 [run|check|force|status|discover]" ;;
esac
