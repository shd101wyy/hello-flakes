#!/usr/bin/env bash
# Control helper for the DeepSeek Harness (dsh) Web UI on Nix machines, where
# the global npm prefix lives in a read-only Nix store and --expose-internals
# cannot be passed via NODE_OPTIONS (Node refuses it there). So the package is
# installed into a user-writable prefix (~/.local/share/dsh) and the server is
# launched directly with node --expose-internals.  Install uses pnpm when
# available: npm 11's resolver spins forever on the dsh peer-dependency
# graph. See README.md "dsh-ctl".
#
# Usage:
#   dsh-ctl install              Install (or update to) the latest @deepseek-ai/dsh
#   dsh-ctl start [--profile NAME] [--port PORT]
#                                 Start the server in the background (default
#                                 profile: web, default port: 3080)
#   dsh-ctl status               Show whether the server is running (pid +
#                                 all reachable URLs, incl. LAN addresses)
#   dsh-ctl stop                 Stop the background server
#   dsh-ctl exec ARGS...         Run the dsh CLI itself, e.g. dsh-ctl exec --help
#
# Named dsh-ctl (not dsh) because `dsh` is the DeepSeek Harness binary itself.
#
# Override the package dir with DSH_ROOT, the bind host with DSH_HOST (e.g.
# the machine's LAN IP, like DSH_HOST=192.168.3.238, to expose it on the LAN;
# dsh refuses 0.0.0.0 by design), the default port with DSH_PORT, or the
# node/npm/pnpm binaries with DSH_NODE / DSH_NPM / DSH_PNPM.
set -euo pipefail

ROOT="${DSH_ROOT:-$HOME/.local/share/dsh}"
NODE_BIN="${DSH_NODE:-$(command -v node)}"
NPM_BIN="${DSH_NPM:-$(command -v npm)}"
PNPM_BIN="${DSH_PNPM:-$(command -v pnpm)}"
PKG="@deepseek-ai/dsh"
HOST="${DSH_HOST:-127.0.0.1}"
PORT="${DSH_PORT:-3080}"
LOG="$ROOT/dsh.log"
PIDFILE="$ROOT/dsh.pid"
STATE="$ROOT/dsh.state"

if [ -z "$NODE_BIN" ] || [ -z "$NPM_BIN" ]; then
  echo "dsh-ctl: node or npm not found on PATH" >&2
  exit 1
fi

# Host the health/status checks connect to (0.0.0.0 is not connectable, use
# loopback for it).
health_host() {
  if [ "$HOST" = "0.0.0.0" ]; then
    echo "127.0.0.1"
  else
    echo "$HOST"
  fi
}

URL="http://$(health_host):${PORT}"

# Non-loopback IPv4 addresses of this machine (used to print reachable URLs).
lan_ips() {
  if command -v hostname >/dev/null 2>&1 && hostname -I >/dev/null 2>&1; then
    hostname -I | tr ' ' '\n' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | grep -v '^127\.' || true
  elif command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY' 2>/dev/null || true
import socket
seen = set()
for r in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET):
    ip = r[4][0]
    if ip not in seen and not ip.startswith(("127.", "169.254.")):
        seen.add(ip)
        print(ip)
PY
  fi
}

# Print every URL on this machine that actually answers: loopback, the bind
# host, and each LAN address (so URLs only appear when they really work).
show_urls() {
  local cand="http://127.0.0.1:$PORT" ip u
  if [ "$HOST" != "127.0.0.1" ]; then
    cand="$cand http://$(health_host):$PORT"
  fi
  for ip in $(lan_ips); do
    cand="$cand http://$ip:$PORT"
  done
  for u in $cand; do
    if curl -sf --max-time 3 -o /dev/null "$u"; then
      echo "$u"
    fi
  done
}

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
  curl -sf --max-time 3 -o /dev/null "$URL"
}

case "${1:-}" in
install)
  mkdir -p "$ROOT"
  # npm 11's arborist spins forever (100% CPU) building the ideal tree for
  # the dsh peer-dependency graph, so use pnpm when it is available.  Resolve
  # the version with `npm view` first: pnpm's own tag handling picks the
  # broken 0.0.1-rc.x line for this package, while the registry's `latest`
  # tag (what `npm view` reports) is the current 0.1.0-rc.x line.
  latest="$("$NPM_BIN" view "$PKG" version 2>/dev/null)" || {
    echo "dsh-ctl: could not resolve the latest $PKG version from the registry" >&2
    exit 1
  }
  if [ -n "$PNPM_BIN" ]; then
    if [ ! -f "$ROOT/pnpm-workspace.yaml" ]; then
      # pnpm 11 blocks dependency build scripts by default; dsh needs them
      # (koffi/node-pty/protobufjs native builds), so allow them all here.
      printf 'dangerouslyAllowAllBuilds: true\n' > "$ROOT/pnpm-workspace.yaml"
    fi
    echo "installing $PKG@$latest into $ROOT ..."
    "$PNPM_BIN" add --dir "$ROOT" "$PKG@$latest"
    # npm runs dependency build scripts with a bundled node-gyp; pnpm does
    # not, and node-pty (a dsh dependency) needs `node-gyp rebuild` on
    # Linux.  node-gyp is a pure-JS dev dep of this scratch project, so add
    # it and rebuild node-pty's native module.
    "$PNPM_BIN" add -D --dir "$ROOT" node-gyp
    "$PNPM_BIN" rebuild --dir "$ROOT" node-pty
  else
    echo "installing $PKG@$latest into $ROOT ..."
    "$NPM_BIN" install --prefix "$ROOT" "$PKG@$latest"
  fi
  echo "installed: $(entry)"
  ;;
start)
  [ -f "$(entry)" ] || {
    echo "not installed yet, run: dsh-ctl install" >&2
    exit 1
  }
  profile="${DSH_PROFILE:-web}"
  local_port="$PORT"
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
    --profile)
      [ $# -ge 2 ] || {
        echo "usage: dsh-ctl start [--profile NAME] [--port PORT]" >&2
        exit 1
      }
      profile="$2"
      shift 2
      ;;
    --profile=*)
      profile="${1#--profile=}"
      shift
      ;;
    --port)
      [ $# -ge 2 ] || {
        echo "usage: dsh-ctl start [--profile NAME] [--port PORT]" >&2
        exit 1
      }
      local_port="$2"
      shift 2
      ;;
    --port=*)
      local_port="${1#--port=}"
      shift
      ;;
    *)
      echo "unknown option: $1" >&2
      echo "usage: dsh-ctl start [--profile NAME] [--port PORT]" >&2
      exit 1
      ;;
    esac
  done
  case "$local_port" in
  (*[!0-9]*)
    echo "invalid port: $local_port" >&2
    exit 1
    ;;
  esac
  case "$profile" in
  (*[!a-zA-Z0-9_-]*)
    echo "invalid profile: $profile" >&2
    exit 1
    ;;
  esac
  PORT="$local_port"
  URL="http://$(health_host):$PORT"
  if [ "$HOST" = "0.0.0.0" ]; then
    echo "dsh refuses --host 0.0.0.0 for safety (would expose remote code" >&2
    echo "execution to the network); bind a specific address instead, e.g." >&2
    echo "DSH_HOST=<your LAN IP> dsh-ctl start" >&2
    exit 1
  fi
  if pid="$(running_pid)"; then
    if [ -f "$STATE" ]; then
      read -r HOST PORT < "$STATE" || true
    fi
    echo "already running (pid $pid) http://$(health_host):$PORT"
    exit 0
  fi
  if port_in_use; then
    echo "port $PORT is already answered by a dsh not started by dsh-ctl (orphan)" >&2
    echo "stop it first, e.g. pkill -f 'dsh.*lib/bin.js'" >&2
    exit 1
  fi
  trusted_flags=""
  if [ "$HOST" != "127.0.0.1" ]; then
    trusted_flags="--trusted-host $HOST --trusted-host $HOST:$PORT"
  fi
  app_args="web"
  if [ "$profile" != "web" ]; then
    app_args="--profile $profile"
  fi
  echo "starting dsh $profile on http://$(health_host):$PORT ..."
  nohup "$NODE_BIN" --expose-internals "$(entry)" $app_args --host "$HOST" --port "$PORT" $trusted_flags > "$LOG" 2>&1 &
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
      printf '%s %s\n' "$HOST" "$PORT" > "$STATE"
      echo "dsh web started (pid $local_pid):"
      show_urls
      exit 0
    fi
    sleep 1
  done
  echo "server did not become healthy within 30s, see $LOG" >&2
  exit 1
  ;;
status)
  if [ -f "$STATE" ]; then
    read -r HOST PORT < "$STATE" || true
    URL="http://$(health_host):$PORT"
  fi
  if pid="$(running_pid)"; then
    echo "dsh web: running (pid $pid)"
    if show_urls | grep -q .; then
      show_urls
    else
      echo "  process alive but not answering on port $PORT"
    fi
  elif show_urls | grep -q .; then
    echo "dsh web: answering on port $PORT but not tracked by dsh-ctl (orphan, not started via dsh-ctl start)"
    show_urls
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
    rm -f "$PIDFILE" "$STATE"
    echo "stopped"
  else
    echo "dsh web: not running"
    rm -f "$PIDFILE" "$STATE"
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
  echo "usage: dsh-ctl {install|start [--profile NAME] [--port PORT]|status|stop|exec ARGS...}" >&2
  exit 1
  ;;
esac
