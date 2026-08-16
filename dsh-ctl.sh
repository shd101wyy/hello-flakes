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
#   dsh-ctl patch                Re-apply the LAN patches: allows --host 0.0.0.0,
#                                 injects a crypto.randomUUID polyfill into the
#                                 web UI (its browser half calls randomUUID,
#                                 which insecure HTTP LAN origins lack), and
#                                 lets the settings/credentials API methods
#                                 honor trusted hosts instead of loopback only
#   dsh-ctl start [web flags...] Start the server in the background. Every
#                                 flag after the dsh-ctl ones is passed
#                                 verbatim to `dsh web`, so
#                                 `dsh-ctl start ARGS...` == `dsh web ARGS...`
#                                 (--host/--port are also read by dsh-ctl for
#                                 its health checks and status output). Each
#                                 port runs its own instance: start again with
#                                 --port to run several servers side by side.
#   dsh-ctl status               Show every running instance (pid + all
#                                 reachable URLs, incl. LAN addresses)
#   dsh-ctl stop                 Stop every running instance
#   dsh-ctl stop --port PORT     Stop just the instance on PORT
#   dsh-ctl restart              Restart every instance (replays each one's
#                                 host, port, profile, and extra web flags)
#   dsh-ctl restart --port PORT  Restart just the instance on PORT
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

# The rejection line carries the actual check `options.host === "0.0.0.0"`;
# keying on that (not on the error message text) survives message rewording.
PATCH_MARKER='options.host === "0.0.0.0"'

# Idempotently apply the LAN patch: delete the startup line that rejects
# --host 0.0.0.0. The installed files are hard links into pnpm's
# content-addressed store, so the patched copy is written to a temp file and
# renamed over the original (atomic; leaves the store entry pristine).
patch_dsh() {
  local f
  f="$(web_startup_file)" || return 1
  PATCH_MARKER="$PATCH_MARKER" "$NODE_BIN" -e '
    const fs = require("node:fs");
    const file = process.argv[1];
    const src = fs.readFileSync(file, "utf8");
    const marker = process.env.PATCH_MARKER;
    const idx = src.indexOf(marker);
    if (idx === -1) {
      console.log(`dsh-ctl: ${file} has no 0.0.0.0 rejection line, nothing to patch`);
      process.exit(0);
    }
    const lineStart = src.lastIndexOf("\n", idx - 1) + 1;
    let lineEnd = src.indexOf("\n", idx);
    if (lineEnd === -1) lineEnd = src.length;
    fs.writeFileSync(`${file}.tmp`, src.slice(0, lineStart) + src.slice(lineEnd));
    fs.renameSync(`${file}.tmp`, file);
    console.log(`dsh-ctl: patched ${file}: --host 0.0.0.0 now allowed`);
  ' "$f"
}

# 0 when the 0.0.0.0 rejection is gone, 1 when dsh still refuses it.
patch_applied() {
  local f
  f="$(web_startup_file)" || return 1
  PATCH_MARKER="$PATCH_MARKER" "$NODE_BIN" -e 'process.exit(require("node:fs").readFileSync(process.argv[1], "utf8").includes(process.env.PATCH_MARKER) ? 1 : 0)' "$f"
}

# The browser half of dsh-client-connection calls crypto.randomUUID(), which
# browsers only expose in secure contexts. http://127.0.0.1 counts as secure
# (loopback), but a plain-HTTP LAN origin like http://192.168.3.243:3080 does
# not, so settings/workspace dialogs crash with "crypto.randomUUID is not a
# function" (iPhone Safari/Brave enforce this strictly). Inject a
# getRandomValues-based UUIDv4 polyfill into the served index.html so the UI
# works from the LAN over plain HTTP too.
frontend_index_file() {
  local pkg_dir
  pkg_dir="$(dirname "$(entry)")"
  "$NODE_BIN" -e '
    const { createRequire } = require("node:module");
    const req = createRequire(process.argv[1]);
    process.stdout.write(req.resolve("@deepseek-ai/dsh-web-frontend/dist/index.html"));
  ' "file://$(realpath "$pkg_dir/package.json")"
}

patch_frontend() {
  local f
  f="$(frontend_index_file)" || return 1
  FRONTEND_POLYFILL="$(cat <<'HTML'
    <script>
      window.crypto.randomUUID || (window.crypto.randomUUID = function () {
        const b = crypto.getRandomValues(new Uint8Array(16));
        b[6] = b[6] & 0x0f | 0x40;
        b[8] = b[8] & 0x3f | 0x80;
        let s = "";
        for (let i = 0; i < 16; i++) {
          if (i === 4 || i === 6 || i === 8 || i === 10) s += "-";
          s += b[i].toString(16).padStart(2, "0");
        }
        return s;
      });
    </script>
HTML
)"
  FRONTEND_POLYFILL="$FRONTEND_POLYFILL" "$NODE_BIN" -e '
    const fs = require("node:fs");
    const file = process.argv[1];
    const src = fs.readFileSync(file, "utf8");
    const marker = "dsh-ctl: crypto.randomUUID polyfill";
    if (src.includes(marker)) {
      console.log(`dsh-ctl: ${file} already has the randomUUID polyfill`);
      process.exit(0);
    }
    const insertAt = src.indexOf("<script type=\"module\"");
    if (insertAt === -1) {
      console.error(`dsh-ctl: no module script tag in ${file}, cannot inject the polyfill`);
      process.exit(1);
    }
    const patched = src.slice(0, insertAt)
      + `    <!-- ${marker} -->\n${process.env.FRONTEND_POLYFILL}\n`
      + src.slice(insertAt);
    fs.writeFileSync(`${file}.tmp`, patched);
    fs.renameSync(`${file}.tmp`, file);
    console.log(`dsh-ctl: patched ${file}: crypto.randomUUID polyfill injected`);
  ' "$f"
}

# The settings/credentials/native-dialog methods (PRIVILEGED_METHODS) are
# deliberately pinned to loopback even on LAN deployments: their gate calls
# isTrustedApiRequest(request, []) with an empty trust list, so LAN browsers
# get HTTP 403 for /api/settings.describe, credentials, host.pickDirectory,
# etc. Lift that by letting the gate honor the configured trustedHosts — the
# same boundary the rest of /api already uses.
client_connection_file() {
  local pkg_dir
  pkg_dir="$(dirname "$(entry)")"
  "$NODE_BIN" -e '
    const { createRequire } = require("node:module");
    const req = createRequire(process.argv[1]);
    process.stdout.write(req.resolve("@deepseek-ai/dsh-client-connection"));
  ' "file://$(realpath "$pkg_dir/package.json")"
}

patch_privileged_gate() {
  local f
  f="$(client_connection_file)" || return 1
  "$NODE_BIN" -e '
    const fs = require("node:fs");
    const file = process.argv[1];
    const src = fs.readFileSync(file, "utf8");
    const old = "PRIVILEGED_METHODS.has(method) && !isTrustedApiRequest(request, [])";
    const fresh = "PRIVILEGED_METHODS.has(method) && !isTrustedApiRequest(request, trustedHosts)";
    if (!src.includes(old)) {
      console.log(`dsh-ctl: ${file} already has the privileged-method gate lifted`);
      process.exit(0);
    }
    const patched = src.replace(old, fresh);
    if (patched === src) {
      console.error(`dsh-ctl: could not patch the privileged-method gate in ${file}`);
      process.exit(1);
    }
    fs.writeFileSync(`${file}.tmp`, patched);
    fs.renameSync(`${file}.tmp`, file);
    console.log(`dsh-ctl: patched ${file}: settings/credentials honor trusted hosts`);
  ' "$f"
}

# Instance bookkeeping is keyed by port: each running instance owns
# dsh.pid.<port> / dsh.state.<port> / dsh.log.<port>, so several dsh web
# servers can run side by side. An empty port maps to the legacy unsuffixed
# names, so instances tracked by older dsh-ctl versions keep working.
pidfile_of_port() {
  [ -n "$1" ] && echo "$PIDFILE.$1" || echo "$PIDFILE"
}
port_of_pidfile() {
  local n
  n="$(basename "$1")"
  n="${n#dsh.pid}"
  n="${n#.}"
  echo "$n"
}
state_of_pidfile() {
  local p
  p="$(port_of_pidfile "$1")"
  [ -n "$p" ] && echo "$STATE.$p" || echo "$STATE"
}
log_of_pidfile() {
  local p
  p="$(port_of_pidfile "$1")"
  [ -n "$p" ] && echo "$LOG.$p" || echo "$LOG"
}
tracked_pidfiles() {
  ls -1 "$PIDFILE"* 2>/dev/null || true
}

# Report the tracked server pid only when it is actually ours. After a reboot
# the pidfile survives but the process does not, and the OS may reuse the
# stale number for an unrelated process: status/start would then lie and stop
# would kill an innocent. On Linux, verify the process's argv names our dsh
# bin; fall back to kill -0 alone where /proc is unavailable.
running_pid() {
  local pidf="$1" pid cmdline
  [ -f "$pidf" ] || return 1
  pid="$(cat "$pidf")"
  [ -n "$pid" ] || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  if [ -r "/proc/$pid/cmdline" ]; then
    cmdline="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)" || return 1
    case "$cmdline" in
    *"$(entry)"*) ;;
    *) return 1 ;;
    esac
  fi
  echo "$pid"
}

port_in_use() {
  curl -sf --max-time 3 -o /dev/null "$URL"
}

# Launch one tracked instance on host:port and wait until it answers HTTP.
# $1 = host, $2 = port, $3 = profile (default web), rest = extra dsh web
# args. Writes dsh.pid.<port> / dsh.state.<port>; the state file carries
# "HOST PORT PROFILE extra args..." so `dsh-ctl restart` can replay the same
# invocation (older two-field state files default profile to web).
start_instance() {
  local start_host="$1" start_port="$2" start_profile="${3:-web}" local_pid a
  shift 3 || true
  PORT="$start_port"
  HOST="$start_host"
  URL="http://$(health_host):$PORT"
  pidfile="$(pidfile_of_port "$PORT")"
  state="$(state_of_pidfile "$pidfile")"
  log="$(log_of_pidfile "$pidfile")"
  if [ "$HOST" = "0.0.0.0" ] && ! patch_applied; then
    echo "dsh still refuses --host 0.0.0.0 (the web app would expose remote" >&2
    echo "code execution to the network). Run 'dsh-ctl patch' to apply the" >&2
    echo "one-line patch, or bind 127.0.0.1 instead." >&2
    return 1
  fi
  if pid="$(running_pid "$pidfile")"; then
    if [ -f "$state" ]; then
      read -r HOST PORT _state_rest < "$state" || true
    fi
    echo "already running (pid $pid) http://$(health_host):$PORT"
    return 0
  fi
  if port_in_use; then
    echo "port $PORT is already answered by a dsh not started by dsh-ctl (orphan)" >&2
    # The [d]sh bracket keeps the pkill pattern from matching the shell that
    # runs it (its own command line contains the literal pattern).
    echo "stop it first, e.g. pkill -f '[d]sh.*lib/bin.js'" >&2
    return 1
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
  if [ "$start_profile" != "web" ]; then
    app_args="--profile $start_profile"
  fi
  echo "starting dsh $start_profile on http://$(health_host):$PORT ..."
  nohup "$NODE_BIN" --expose-internals "$(entry)" $app_args --host "$HOST" --port "$PORT" $trusted_flags "$@" > "$log" 2>&1 &
  local_pid=$!
  echo "$local_pid" > "$pidfile"
  for _ in $(seq 1 30); do
    if ! kill -0 "$local_pid" 2>/dev/null; then
      echo "dsh web exited during startup, tail of $log:" >&2
      tail -20 "$log" >&2
      rm -f "$pidfile"
      return 1
    fi
    if port_in_use; then
      printf '%s %s %s' "$HOST" "$PORT" "$start_profile" > "$state"
      for a in "$@"; do
        printf ' %s' "$a" >> "$state"
      done
      printf '\n' >> "$state"
      echo "dsh web started (pid $local_pid):"
      show_urls
      return 0
    fi
    sleep 1
  done
  echo "server did not become healthy within 30s, see $log" >&2
  return 1
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
  patch_frontend || echo "dsh-ctl: warning: could not apply the randomUUID polyfill (run 'dsh-ctl patch' later)" >&2
  patch_privileged_gate || echo "dsh-ctl: warning: could not lift the privileged-method loopback gate (run 'dsh-ctl patch' later)" >&2
  ;;
patch)
  [ -f "$(entry)" ] || {
    echo "not installed yet, run: dsh-ctl install" >&2
    exit 1
  }
  if ! patch_dsh; then
    echo "dsh-ctl: could not locate @deepseek-ai/dsh-web-app/lib/startup.js in $ROOT (is it installed?)" >&2
    exit 1
  fi
  if ! patch_frontend; then
    echo "dsh-ctl: could not locate @deepseek-ai/dsh-web-frontend/dist/index.html in $ROOT (is it installed?)" >&2
    exit 1
  fi
  if ! patch_privileged_gate; then
    echo "dsh-ctl: could not locate @deepseek-ai/dsh-client-connection/lib/index.js in $ROOT (is it installed?)" >&2
    exit 1
  fi
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
      # dsh-ctl start --help is the profile app's --help: print its usage and
      # exit instead of backgrounding a process that exits immediately.
      if [ "$profile" = "web" ]; then
        exec "$NODE_BIN" --expose-internals "$(entry)" web "$@"
      else
        exec "$NODE_BIN" --expose-internals "$(entry)" --profile "$profile" "$@"
      fi
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
  start_instance "$local_host" "$local_port" "$profile" "${extra_args[@]}"
  ;;
status)
  found=0
  for pidfile in $(tracked_pidfiles); do
    state="$(state_of_pidfile "$pidfile")"
    # Each instance carries its own bind host/port in its state file.
    HOST="127.0.0.1"
    PORT="$(port_of_pidfile "$pidfile")"
    [ -n "$PORT" ] || PORT="${DSH_PORT:-3080}"
    if [ -f "$state" ]; then
      read -r HOST PORT _state_rest < "$state" || true
    fi
    URL="http://$(health_host):$PORT"
    # Collect the URL list before testing it: `show_urls | grep -q .` would
    # close the pipe after the first match, SIGPIPE the remaining curls, and
    # fail the whole pipeline under set -o pipefail.
    urls="$(show_urls)" || true
    if pid="$(running_pid "$pidfile")"; then
      found=1
      echo "dsh web: running (pid $pid):"
      if [ -n "$urls" ]; then
        printf '%s\n' "$urls" | sed 's/^/  /'
      else
        echo "  process alive but not answering on port $PORT"
      fi
    elif [ -n "$urls" ]; then
      found=1
      echo "dsh web: answering on port $PORT but not tracked by dsh-ctl (orphan, not started via dsh-ctl start):"
      printf '%s\n' "$urls" | sed 's/^/  /'
    else
      # Tracked instance is down (crash or reboot). Keep the tracking files
      # so `dsh-ctl restart` can revive it from its recorded launch.
      found=1
      echo "dsh web: down (port $PORT) -- 'dsh-ctl restart' revives it"
    fi
  done
  if [ "$found" = 0 ]; then
    echo "dsh web: not running"
  fi
  ;;
stop)
  stop_port=""
  shift || true
  while [ $# -gt 0 ]; do
    case "$1" in
    --port)
      [ $# -ge 2 ] || {
        echo "usage: dsh-ctl stop [--port PORT]" >&2
        exit 1
      }
      stop_port="$2"
      shift 2
      ;;
    --port=*)
      stop_port="${1#--port=}"
      shift
      ;;
    *)
      echo "unknown option: $1" >&2
      echo "usage: dsh-ctl stop [--port PORT]" >&2
      exit 1
      ;;
    esac
  done
  if [ -n "$stop_port" ]; then
    case "$stop_port" in
    (*[!0-9]*)
      echo "invalid port: $stop_port" >&2
      exit 1
      ;;
    esac
  fi
  # Stop one instance (--port PORT) or every tracked instance.
  matched=0
  for pidfile in $(tracked_pidfiles); do
    if [ -n "$stop_port" ] && [ "$(port_of_pidfile "$pidfile")" != "$stop_port" ]; then
      continue
    fi
    matched=1
    state="$(state_of_pidfile "$pidfile")"
    if pid="$(running_pid "$pidfile")"; then
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
    else
      echo "dsh web: not running (stale tracking files for $(port_of_pidfile "$pidfile") removed)"
    fi
    rm -f "$pidfile" "$state"
  done
  if [ "$matched" = 0 ]; then
    if [ -n "$stop_port" ]; then
      echo "dsh web: no instance tracked on port $stop_port"
    else
      echo "dsh web: not running"
    fi
  fi
  ;;
restart)
  [ -f "$(entry)" ] || {
    echo "not installed yet, run: dsh-ctl install" >&2
    exit 1
  }
  restart_port=""
  shift || true
  while [ $# -gt 0 ]; do
    case "$1" in
    --port)
      [ $# -ge 2 ] || {
        echo "usage: dsh-ctl restart [--port PORT]" >&2
        exit 1
      }
      restart_port="$2"
      shift 2
      ;;
    --port=*)
      restart_port="${1#--port=}"
      shift
      ;;
    *)
      echo "unknown option: $1" >&2
      echo "usage: dsh-ctl restart [--port PORT]" >&2
      exit 1
      ;;
    esac
  done
  if [ -n "$restart_port" ]; then
    case "$restart_port" in
    (*[!0-9]*)
      echo "invalid port: $restart_port" >&2
      exit 1
      ;;
    esac
  fi
  # Restart one instance (--port PORT) or every tracked one, replaying each
  # instance's host, port, profile, and extra dsh web args from its state
  # file. Instances that died (e.g. after a reboot) are just started again.
  matched=0
  for pidfile in $(tracked_pidfiles); do
    if [ -n "$restart_port" ] && [ "$(port_of_pidfile "$pidfile")" != "$restart_port" ]; then
      continue
    fi
    matched=1
    state="$(state_of_pidfile "$pidfile")"
    HOST="127.0.0.1"
    PORT="$(port_of_pidfile "$pidfile")"
    [ -n "$PORT" ] || PORT="${DSH_PORT:-3080}"
    profile="web"
    args=()
    rest=""
    if [ -f "$state" ]; then
      read -r HOST PORT profile rest < "$state" || true
      for a in $rest; do
        args+=("$a")
      done
    fi
    if pid="$(running_pid "$pidfile")"; then
      echo "restarting dsh web on $HOST:$PORT (pid $pid)"
      kill "$pid"
      for _ in $(seq 1 10); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.5
      done
      if kill -0 "$pid" 2>/dev/null; then
        echo "still alive after 5s, sending SIGKILL"
        kill -9 "$pid"
      fi
    else
      echo "restarting dsh web on $HOST:$PORT (not running, starting)"
    fi
    rm -f "$pidfile" "$state"
    start_instance "$HOST" "$PORT" "$profile" "${args[@]}" || echo "dsh-ctl: restart of $HOST:$PORT failed" >&2
  done
  if [ "$matched" = 0 ]; then
    if [ -n "$restart_port" ]; then
      echo "dsh web: no instance tracked on port $restart_port"
    else
      echo "dsh web: not running (nothing to restart)"
    fi
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
  echo "usage: dsh-ctl {install|patch|start [--profile NAME] [dsh web flags...]|status|stop [--port PORT]|restart [--port PORT]|exec ARGS...}" >&2
  exit 1
  ;;
esac
