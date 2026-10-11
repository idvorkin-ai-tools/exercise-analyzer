#!/usr/bin/env bash
# Event stream for an agent Monitor: the issues the bug-kit listener filed for this app. The listener
# (bug-kit's listener/bug-listener, always on in a Herdr pane, every five minutes, every paired iPhone and iPad)
# pulls each new report and crash, files the issue and appends one line to ~/tmp/agent/bugs/inbox.jsonl; this
# script prints those lines for exercise-analyzer as they land (`filed <kind> <device> <issue url> <note>`), so the
# agent is woken to fix, never to file (`just file-bugs` next to a live listener files the same report twice).
# It also watches the listener itself, once on arming and then every poll interval, one line per change:
# `listener_stale <age>` when status.json shows no completed poll for three intervals, `listener_missing` when there
# is no status at all, `listener_ok` when it is back; a dead listener must not look like a quiet phone.
# Usage: scripts/bugs-monitor.sh          (BUGS_STATE=<dir> points at another state folder, for tests)
set -uo pipefail
STATE="${BUGS_STATE:-$HOME/tmp/agent/bugs}"
APP=exercise-analyzer

listener_state() {
  local status="$STATE/status.json" last every age
  [ -f "$status" ] || { echo "missing no $status"; return; }
  last=$(jq -r '.last_poll_completed // empty' "$status")
  every=$(jq -r '.poll_seconds // 300' "$status")
  [ -n "$last" ] || { echo "missing no completed poll in $status"; return; }
  age=$(( $(date +%s) - $(date -j -u -f '%Y-%m-%dT%H:%M:%S' "${last%%.*}" +%s) ))
  if [ "$age" -gt $(( every * 3 )) ]; then echo "stale ${age}s since the last poll (every ${every}s)"; else echo ok; fi
}

watch_listener() {
  local state=ok now
  while true; do
    now=$(listener_state)
    if [ "${now%% *}" != "${state%% *}" ]; then
      if [ "$now" = ok ]; then echo "listener_ok"; else echo "listener_$now"; fi
      state=$now
    fi
    sleep "${BUGS_EVERY:-$(jq -r '.poll_seconds // 300' "$STATE/status.json" 2>/dev/null || echo 300)}"
  done
}
watch_listener &
WATCH=$!

mkdir -p "$STATE" && touch "$STATE/inbox.jsonl"
( tail -n 0 -F "$STATE/inbox.jsonl" | jq --unbuffered -r --arg app "$APP" \
  'select(.app == $app) | "filed \(.kind) \(.device) \(.ref // "no-ref") \(.note // "" | gsub("\n"; " "))"' ) &
PIPE=$!
# The Monitor harness ends the watch by killing this script: take the watcher and the tail pipeline (the subshell's
# children) along, or every expired monitor leaves a `tail -F` behind.
trap 'pkill -P "$PIPE" 2>/dev/null; kill "$PIPE" "$WATCH" 2>/dev/null' EXIT TERM INT
wait "$PIPE"
