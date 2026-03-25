#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <name> <command>" >&2
  exit 1
fi

name="$1"
shift
command="$*"

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
run_dir="$repo_root/tmp/local-run"
mkdir -p "$run_dir"

log_file="$run_dir/${name}.log"
status_file="$run_dir/${name}.status"

restart_count=0
backoff_seconds=1
max_backoff_seconds=5

write_status() {
  local state="$1"
  local child_pid="${2:-}"
  cat >"$status_file" <<EOF
state=$state
supervisor_pid=$$
child_pid=$child_pid
restart_count=$restart_count
timestamp=$(date +%s)
command=$command
EOF
}

cleanup() {
  local exit_code=$?
  if [[ -n "${child_pid:-}" ]] && kill -0 "${child_pid}" 2>/dev/null; then
    kill "${child_pid}" 2>/dev/null || true
    wait "${child_pid}" 2>/dev/null || true
  fi
  write_status "stopped"
  exit "$exit_code"
}

trap cleanup EXIT INT TERM

touch "$log_file"
write_status "starting"

while true; do
  write_status "running"
  (
    cd "$repo_root"
    exec bash -lc "$command"
  ) >>"$log_file" 2>&1 &
  child_pid=$!
  write_status "running" "$child_pid"

  if wait "$child_pid"; then
    exit_code=0
  else
    exit_code=$?
  fi
  child_pid=""

  if [[ $exit_code -eq 0 ]]; then
    write_status "exited"
    exit 0
  fi

  restart_count=$((restart_count + 1))
  write_status "restarting"
  {
    printf '[%s] %s exited with code %s, restarting in %ss\n' \
      "$(date '+%Y-%m-%d %H:%M:%S')" \
      "$name" \
      "$exit_code" \
      "$backoff_seconds"
  } >>"$log_file"
  sleep "$backoff_seconds"
  if (( backoff_seconds < max_backoff_seconds )); then
    backoff_seconds=$((backoff_seconds + 1))
  fi
done
