#!/usr/bin/env bash
# Control helper for the DeepSeek Harness (dsh) Web UI on Nix machines, where
# the global npm prefix lives in a read-only Nix store and --expose-internals
# cannot be passed via NODE_OPTIONS (Node refuses it there). So the package is
# installed into a user-writable prefix (~/.local/share/dsh) and the server is
# launched directly with node --expose-internals. See README.md "dsh-ctl".
#
# Usage:
#   dsh-ctl install              Install (or update to) the latest @deepseek-ai/dsh
#   dsh-ctl start                Start the Web UI server in the background
#   dsh-ctl status               Show whether the server is running (pid + health)
#   dsh-ctl stop                 Stop the background server
#   dsh-ctl exec ARGS...         Run the dsh CLI itself, e.g. dsh-ctl exec --help
#
# Named dsh-ctl (not dsh) because `dsh` is the DeepSeek Harness binary itself.
#
# Override locations with DSH_ROOT (package install dir), the port with
# DSH_PORT, or the node/npm binaries with DSH_NODE / DSH_NPM.
set -euo pipefail

ROOT="${DSH_ROOT:-$HOME/.local/share/dsh}"
NODE_BIN="${DSH_NODE:-$(command -v node)}"
NPM_BIN="${DSH_NPM:-$(command -v npm)}"
PORT="${DSH_PORT:-3080}"
URL="http://127.0.0.1:${PORT}"
LOG="$ROOT/dsh.log"
PIDFILE="$ROOT/dsh.pid"

if [ -z "$NODE_BIN" ] || [ -z "$NPM_BIN" ]; then
  echo "dsh-ctl: node or npm not found on PATH" >&2
  exit 1
fi

entry() {
  local pkg="$ROOT/node_modules/@deepseek-ai/dsh"
  "$NODE_BIN" -e "const j = require(process.argv[1] + '/package.json'); process.stdout.write(process.argv[1] + '/' + j.bin.dsh)" "$pkg"
}

running_pid() {
  [ -f "$PIDFILE" ] || return 1
  local pid
  pid="$(cat "$PIDFILE")"
  [ -n "$pid" ] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  echo "$pid"
}

port_in_use() {
  curl -sf -o /dev/null "$URL"
}

case "${1:-}" in
install)
  mkdir -p "$ROOT"
  echo "installing @deepseek-ai/dsh into $ROOT ..."
  "$NPM_BIN" install --prefix "$ROOT" @deepseek-ai/dsh
  echo "installed: $(entry)"
  ;;
start)
  [ -f "$(entry)" ] || {
    echo "not installed yet, run: dsh-ctl install" >&2
    exit 1
  }
  if pid="$(running_pid)"; then
    echo "already running (pid $pid) $URL"
    exit 0
  fi
  if port_in_use; then
    echo "port $PORT is already answered by a dsh not started by dsh-ctl (orphan)" >&2
    echo "stop it first, e.g. pkill -f 'dsh.*lib/bin.js web'" >&2
    exit 1
  fi
  mkdir -p "$ROOT"
  echo "starting dsh web on $URL ..."
  nohup "$NODE_BIN" --expose-internals "$(entry)" web >> "$LOG" 2>&1 &
  local_pid=$!
  echo "$local_pid" > "$PIDFILE"
  for _ in $(seq 1 30); do
    if ! kill -0 "$local_pid" 2>/dev/null; then
      echo "dsh web exited during startup, tail of $LOG:" >&2
      tail -20 "$LOG" >&2
      rm -f "$PIDFILE"
      exit 1
    fi
    if port_in_use; then
      echo "dsh web: http://127.0.0.1:$PORT (pid $local_pid)"
      exit 0
    fi
    sleep 1
  done
  echo "server did not become healthy within 30s, see $LOG" >&2
  exit 1
  ;;
status)
  if pid="$(running_pid)"; then
    if port_in_use; then
      echo "dsh web: running (pid $pid) $URL"
    else
      echo "dsh web: process $pid alive but not answering on $URL"
    fi
  elif port_in_use; then
    echo "dsh web: answering on $URL but not tracked by dsh-ctl (orphan, not started via dsh-ctl start)"
  else
    echo "dsh web: not running"
  fi
  ;;
stop)
  if pid="$(running_pid)"; then
    echo "stopping dsh web (pid $pid)"
    kill "$pid"
    for _ in $(seq 1 10); do
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.5
    done
    if kill -0 "$pid" 2>/dev/null; then
      echo "still alive after 5s, sending SIGKILL"
      kill -9 "$pid"
    fi
    rm -f "$PIDFILE"
    echo "stopped"
  else
    echo "dsh web: not running"
    rm -f "$PIDFILE"
  fi
  ;;
exec)
  [ -f "$(entry)" ] || {
    echo "not installed yet, run: dsh-ctl install" >&2
    exit 1
  }
  shift
  exec "$NODE_BIN" --expose-internals "$(entry)" "$@"
  ;;
*)
  echo "usage: dsh-ctl {install|start|status|stop|exec ARGS...}" >&2
  exit 1
  ;;
esac
