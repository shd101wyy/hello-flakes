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
#   dsh-ctl patch                Re-apply the LAN patch (allows --host 0.0.0.0)
#   dsh-ctl start [web flags...] Start the server in the background. Every
#                                 flag after the dsh-ctl ones is passed
#                                 verbatim to `dsh web`, so
#                                 `dsh-ctl start ARGS...` == `dsh web ARGS...`
#                                 (--host/--port are also read by dsh-ctl for
#                                 its health checks and status output).
#   dsh-ctl status               Show whether the server is running (pid +
#                                 all reachable URLs, incl. LAN addresses)
#   dsh-ctl stop                 Stop the background server
#   dsh-ctl exec ARGS...         Run the dsh CLI itself, e.g. dsh-ctl exec --help
#
# Named dsh-ctl (not dsh) because `dsh` is the DeepSeek Harness binary itself.
#
# Override the package dir with DSH_ROOT, the bind host with DSH_HOST, the
# default port with DSH_PORT, or the node/npm/pnpm binaries with
# DSH_NODE / DSH_NPM / DSH_PNPM.
# dsh's web app refuses --host 0.0.0.0 for now (it would expose remote code
# execution to the network); `install` and `patch` remove that one-line
# rejection from @deepseek-ai/dsh-web-app's startup. With the patch,
# DSH_HOST=0.0.0.0 binds every interface and dsh derives its own LAN trust
# list from the interfaces, so http://<LAN IP>:3080 works from other devices
# on the LAN. There is no authentication layer: whoever can reach the port
# gets full remote code execution, and binding 0.0.0.0 also exposes the Web
# UI on every other interface (Tailscale, VPNs, ...).
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
  local cand="http://127.0.0.1:$PORT" ip u seen=""
  if [ "$HOST" != "127.0.0.1" ]; then
    cand="$cand http://$(health_host):$PORT"
  fi
  for ip in $(lan_ips); do
    cand="$cand http://$ip:$PORT"
  done
  for u in $cand; do
    case " $seen " in
    *" $u "*) continue ;;
    esac
    if curl -sf --max-time 3 -o /dev/null "$u"; then
      echo "$u"
      seen="$seen $u"
    fi
  done
}

entry() {
  local pkg="$ROOT/node_modules/@deepseek-ai/dsh"
  "$NODE_BIN" -e "const j = require(process.argv[1] + '/package.json'); process.stdout.write(process.argv[1] + '/' + j.bin.dsh)" "$pkg"
}

# Resolve @deepseek-ai/dsh-web-app's startup file through dsh's own dependency
# graph (pnpm lays deps out under the dsh package's node_modules, keyed by
# version), so the path stays correct across dsh updates. createRequire needs
# the file:// URL form: the plain-path form realpaths and resolves from a
# different base.
web_startup_file() {
  local pkg_dir
  pkg_dir="$(dirname "$(entry)")"
  "$NODE_BIN" -e '
    const { createRequire } = require("node:module");
    const req = createRequire(process.argv[1]);
    process.stdout.write(req.resolve("@deepseek-ai/dsh-web-app/startup"));
  ' "file://$(realpath "$pkg_dir/package.json")"
}

# Idempotently apply the LAN patch: delete the startup line that rejects
# --host 0.0.0.0. The installed files are hard links into pnpm's
# content-addressed store, so the patched copy is written over a fresh inode
# (unlink + write), leaving the store entry pristine.
patch_dsh() {
  local f
  f="$(web_startup_file)" || return 1
  "$NODE_BIN" -e '
    const fs = require("node:fs");
    const file = process.argv[1];
    const src = fs.readFileSync(file, "utf8");
    const line = src.match(/^[^\n]*intentionally not supported[^\n]*\n?/m);
    if (!line) {
      console.log(`dsh-ctl: ${file} has no 0.0.0.0 rejection line, nothing to patch`);
      process.exit(0);
    }
    fs.unlinkSync(file);
    fs.writeFileSync(file, src.replace(line[0], ""));
    console.log(`dsh-ctl: patched ${file}: --host 0.0.0.0 now allowed`);
  ' "$f"
}

# 0 when the 0.0.0.0 rejection is gone, 1 when dsh still refuses it.
patch_applied() {
  local f
  f="$(web_startup_file)" || return 1
  "$NODE_BIN" -e 'process.exit(require("node:fs").readFileSync(process.argv[1], "utf8").includes("intentionally not supported") ? 1 : 0)' "$f"
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
  patch_dsh || echo "dsh-ctl: warning: could not apply the LAN patch (run 'dsh-ctl patch' later)" >&2
  ;;
patch)
  [ -f "$(entry)" ] || {
    echo "not installed yet, run: dsh-ctl install" >&2
    exit 1
  }
  patch_dsh
  ;;
start)
  [ -f "$(entry)" ] || {
    echo "not installed yet, run: dsh-ctl install" >&2
    exit 1
  }
  profile="${DSH_PROFILE:-web}"
  local_port="$PORT"
  local_host="$HOST"
  extra_args=()
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
    --profile)
      [ $# -ge 2 ] || {
        echo "usage: dsh-ctl start [--profile NAME] [dsh web flags...]" >&2
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
        echo "usage: dsh-ctl start [--profile NAME] [dsh web flags...]" >&2
        exit 1
      }
      local_port="$2"
      shift 2
      ;;
    --port=*)
      local_port="${1#--port=}"
      shift
      ;;
    --host)
      [ $# -ge 2 ] || {
        echo "usage: dsh-ctl start [--profile NAME] [dsh web flags...]" >&2
        exit 1
      }
      local_host="$2"
      shift 2
      ;;
    --host=*)
      local_host="${1#--host=}"
      shift
      ;;
    --help|-h)
      # dsh-ctl start --help is dsh web --help: print the app's usage and
      # exit instead of backgrounding a process that exits immediately.
      exec "$NODE_BIN" --expose-internals "$(entry)" web "$@"
      ;;
    *)
      # Everything else is a `dsh web` flag (--trusted-host, ...); forward it
      # verbatim so `dsh-ctl start ARGS...` behaves like `dsh web ARGS...`.
      extra_args+=("$1")
      shift
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
  HOST="$local_host"
  URL="http://$(health_host):$PORT"
  if [ "$HOST" = "0.0.0.0" ] && ! patch_applied; then
    echo "dsh still refuses --host 0.0.0.0 (the web app would expose remote" >&2
    echo "code execution to the network). Run 'dsh-ctl patch' to apply the" >&2
    echo "one-line patch, or bind 127.0.0.1 instead." >&2
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
  # Non-loopback bind hosts are passed as --trusted-host (IP literal and its
  # :PORT form) so the /api trusted-host fence accepts browser requests to them.
  # For 0.0.0.0 dsh derives the LAN IPs it trusts from the interfaces itself,
  # so no trusted-host flags are needed there.
  trusted_flags=""
  if [ "$HOST" != "127.0.0.1" ] && [ "$HOST" != "0.0.0.0" ]; then
    trusted_flags="--trusted-host $HOST --trusted-host $HOST:$PORT"
  fi
  app_args="web"
  if [ "$profile" != "web" ]; then
    app_args="--profile $profile"
  fi
  echo "starting dsh $profile on http://$(health_host):$PORT ..."
  nohup "$NODE_BIN" --expose-internals "$(entry)" $app_args --host "$HOST" --port "$PORT" $trusted_flags "${extra_args[@]}" > "$LOG" 2>&1 &
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
  # Collect the URL list before testing it: `show_urls | grep -q .` would
  # close the pipe after the first match, SIGPIPE the remaining curls, and
  # fail the whole pipeline under set -o pipefail.
  urls="$(show_urls)" || true
  if pid="$(running_pid)"; then
    echo "dsh web: running (pid $pid)"
    if [ -n "$urls" ]; then
      printf '%s\n' "$urls"
    else
      echo "  process alive but not answering on port $PORT"
    fi
  elif [ -n "$urls" ]; then
    echo "dsh web: answering on port $PORT but not tracked by dsh-ctl (orphan, not started via dsh-ctl start)"
    printf '%s\n' "$urls"
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
  echo "usage: dsh-ctl {install|patch|start [--profile NAME] [dsh web flags...]|status|stop|exec ARGS...}" >&2
  exit 1
  ;;
esac
