#!/usr/bin/env bash
# Control helper for the headless mihomo (Clash Meta) proxy service on the
# Steam Deck. Installed to ~/.local/bin/mihomo-ctl by home-manager (see
# home/yiyiwang-steamdeck-home.nix). See README.md "Mihomo on Steam Deck".
#
# Usage:
#   mihomo-ctl status             Provider summary + node health (UP/DOWN, last delay)
#   mihomo-ctl providers          List all subscription providers
#   mihomo-ctl nodes              Just the node list (UP/DOWN)
#   mihomo-ctl current            Show which node the PROXY group is using now
#   mihomo-ctl test               Live latency of every node (5s timeout each)
#   mihomo-ctl set-node "NAME"    Manually pick a node for the PROXY group
#   mihomo-ctl stop               Stop using nodes (PROXY group -> DIRECT)
#   mihomo-ctl refresh            Force a subscription refresh now; on failure
#                                 retries once via DIRECT (see refresh_provider)
#   mihomo-ctl refresh-if-dead    Refresh only when every node is dead and the last
#                                 refresh is older than 1h (used by the systemd timer)
#
# By default all commands cover every subscription provider. Restrict to one
# with MIHOMO_PROVIDER, e.g. MIHOMO_PROVIDER=jms mihomo-ctl test.
# Internal "compatible" providers (created by mihomo for the built-in groups)
# are always skipped; only real HTTP subscriptions are shown.
#
# Named mihomo-ctl (not mihomo) because `mihomo` is the Clash Meta binary
# itself, installed by nixpkgs into ~/.nix-profile/bin ahead of ~/.local/bin
# on PATH.
#
# The Clash API listens on 127.0.0.1:9090 (external-controller in the mihomo
# config). Override with MIHOMO_API / MIHOMO_GROUP.
set -euo pipefail

API="${MIHOMO_API:-http://127.0.0.1:9090}"
GROUP="${MIHOMO_GROUP:-PROXY}"
PROVIDER="${MIHOMO_PROVIDER:-}"
PY="$(command -v python3 || echo /usr/bin/python3)"

# Every curl below talks only to the local mihomo API. Never let
# http(s)_proxy env vars (exported by this repo's shells for mihomo's own
# mixed port) loop the control channel through mihomo itself -- same reason
# the python snippets use ProxyHandler({}).
CURL=(curl -sSf --noproxy '*')

# Point the PROXY group at $1 (a node name, AUTO or DIRECT).
select_group() {
  "${CURL[@]}" -X PUT "$API/proxies/$GROUP" \
    -H "Content-Type: application/json" -d "{\"name\":\"$1\"}"
}

# Refresh one subscription provider. mihomo downloads subscriptions through
# the rule engine, so with a dead node selected in the PROXY group the
# download itself fails (controller answers 503) -- the outage blocks its
# own fix. On failure: switch the group to DIRECT, retry once, then hand the
# group to AUTO so url-test uses the fresh nodes.
refresh_provider() {
  name="$1"
  echo "refreshing $name"
  if "${CURL[@]}" -X PUT "$API/providers/proxies/$name" -w "  HTTP %{http_code}\n"; then
    return 0
  fi
  echo "  refresh failed, switching $GROUP to DIRECT and retrying" >&2
  select_group DIRECT >/dev/null 2>&1 || true
  if "${CURL[@]}" -X PUT "$API/providers/proxies/$name" -w "  HTTP %{http_code}\n"; then
    if select_group AUTO >/dev/null 2>&1; then
      echo "  $GROUP switched to AUTO (fastest alive node)"
    fi
    return 0
  fi
  echo "  refresh still failing after DIRECT retry" >&2
  return 1
}

case "${1:-}" in
providers)
  "$PY" - "$API" <<'PY'
import json, sys, urllib.request
api = sys.argv[1]
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
d = json.load(opener.open(f"{api}/providers/proxies", timeout=10))
for name in sorted(d.get("providers", d)):
    p = d["providers"][name]
    if p.get("vehicleType") != "HTTP":
        continue
    proxies = p.get("proxies", [])
    alive = sum(1 for x in proxies if x.get("alive"))
    print(f"{name}: {len(proxies)} nodes, {alive} alive, updated {p.get('updatedAt')}")
PY
  ;;
status)
  "$PY" - "$API" "$GROUP" "$PROVIDER" <<'PY'
import json, sys, urllib.parse, urllib.request
api, group, only = sys.argv[1], sys.argv[2], sys.argv[3] or None
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
d = json.load(opener.open(f"{api}/providers/proxies", timeout=10))
provs = d.get("providers", d)
g = json.load(opener.open(f"{api}/proxies/{urllib.parse.quote(group, safe='')}", timeout=10))
current = g.get("now")
print(f"group: {g.get('name')} ({g.get('type')})  current: {current}")
for name in sorted(provs):
    if only and name != only:
        continue
    p = provs[name]
    if p.get("vehicleType") != "HTTP":
        continue
    proxies = p.get("proxies", [])
    print(f"provider: {name}  updatedAt: {p.get('updatedAt')}")
    print(f"nodes: {len(proxies)}  alive: {sum(1 for x in proxies if x.get('alive'))}")
    for pr in proxies:
        last = "n/a"
        hist = pr.get("history") or []
        if hist:
            last = f"{hist[-1].get('delay')}ms"
        mark = "UP  " if pr.get("alive") else "DOWN"
        sel = "  <- current" if pr.get("name") == current else ""
        print(f"  {mark} {pr.get('name')}  {last}{sel}")
PY
  ;;
nodes)
  "$PY" - "$API" "$PROVIDER" <<'PY'
import json, sys, urllib.request
api, only = sys.argv[1], sys.argv[2] or None
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
d = json.load(opener.open(f"{api}/providers/proxies", timeout=10))
provs = d.get("providers", d)
for name in sorted(provs):
    if only and name != only:
        continue
    p = provs[name]
    if p.get("vehicleType") != "HTTP":
        continue
    for pr in p.get("proxies", []):
        mark = "UP  " if pr.get("alive") else "DOWN"
        print(f"{name:12} {mark} {pr.get('name')}")
PY
  ;;
current)
  "$PY" - "$API" "$GROUP" <<'PY'
import json, sys, urllib.parse, urllib.request
api, group = sys.argv[1], sys.argv[2]
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
url = f"{api}/proxies/{urllib.parse.quote(group, safe='')}"
d = json.load(opener.open(url, timeout=10))
print(f"group: {d.get('name')} ({d.get('type')})")
print(f"current: {d.get('now')}")
PY
  ;;
test)
  "$PY" - "$API" "$PROVIDER" <<'PY'
import json, sys, urllib.parse, urllib.request
api, only = sys.argv[1], sys.argv[2] or None
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
d = json.load(opener.open(f"{api}/providers/proxies", timeout=10))
provs = d.get("providers", d)
for name in sorted(provs):
    if only and name != only:
        continue
    p = provs[name]
    if p.get("vehicleType") != "HTTP":
        continue
    for pr in p.get("proxies", []):
        node = pr.get("name")
        url = f"{api}/providers/proxies/{name}/{urllib.parse.quote(node, safe='')}/healthcheck?timeout=5000&url=http://www.gstatic.com/generate_204"
        try:
            r = json.load(opener.open(url, timeout=10))
            print(f"{name:12} {node} -> {r.get('delay')}ms")
        except Exception:
            print(f"{name:12} {node} -> FAIL")
PY
  ;;
set-node)
  node="${2:-}"
  if [ -z "$node" ]; then
    echo "usage: mihomo-ctl set-node \"NODE NAME\"" >&2
    exit 1
  fi
  "${CURL[@]}" -X PUT "$API/proxies/$GROUP" -H "Content-Type: application/json" -d "{\"name\":\"$node\"}" -w "set-node: HTTP %{http_code}\n"
  ;;
stop)
  # Stop using nodes: the PROXY group selects DIRECT. mihomo itself keeps
  # running (local/CN traffic unaffected); apps using the proxy connect
  # directly until set-node "AUTO" or set-node "NAME" is run again.
  select_group DIRECT
  echo "$GROUP -> DIRECT (stopped using node)"
  ;;
refresh)
  # Provider names are sanitized to [a-zA-Z0-9_-] by the activation hook,
  # so plain word splitting over $names is safe.
  names="$("$PY" - "$API" "$PROVIDER" <<'PY'
import json, sys, urllib.request
api, only = sys.argv[1], sys.argv[2] or None
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
d = json.load(opener.open(f"{api}/providers/proxies", timeout=10))
provs = d.get("providers", d)
for name in sorted(provs):
    if only and name != only:
        continue
    if provs[name].get("vehicleType") != "HTTP":
        continue
    print(name)
PY
)"
  rc=0
  for name in $names; do
    refresh_provider "$name" || rc=1
  done
  exit $rc
  ;;
refresh-if-dead)
  stale="$("$PY" - "$API" "$PROVIDER" <<'PY'
import json, sys, urllib.request, datetime
api, only = sys.argv[1], sys.argv[2] or None
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
d = json.load(opener.open(f"{api}/providers/proxies", timeout=10))
provs = d.get("providers", d)
for name in sorted(provs):
    if only and name != only:
        continue
    p = provs[name]
    if p.get("vehicleType") != "HTTP":
        continue
    proxies = p.get("proxies", [])
    if proxies and any(x.get("alive") for x in proxies):
        continue
    try:
        updated = datetime.datetime.fromisoformat(p["updatedAt"].replace("Z", "+00:00"))
        age = (datetime.datetime.now(updated.tzinfo) - updated).total_seconds()
    except Exception:
        age = float("inf")
    if age > 3600:
        print(name)
PY
  )"
  if [ -n "$stale" ]; then
    rc=0
    for name in $stale; do
      echo "all nodes dead for provider '$name' and last refresh older than 1h, refreshing subscription"
      refresh_provider "$name" || rc=1
    done
    exit $rc
  else
    echo "no refresh needed"
  fi
  ;;
*)
  echo "usage: mihomo-ctl {status|providers|nodes|current|test|set-node \"NAME\"|stop|refresh|refresh-if-dead}" >&2
  exit 1
  ;;
esac
