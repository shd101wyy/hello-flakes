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
#   mihomo-ctl refresh            Force a subscription refresh now
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
  curl -sf -X PUT "$API/proxies/$GROUP" -H "Content-Type: application/json" -d "{\"name\":\"$node\"}" -w "set-node: HTTP %{http_code}\n"
  ;;
refresh)
  "$PY" - "$API" "$PROVIDER" <<'PY' | while IFS= read -r name; do
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
    echo "refreshing $name"
    curl -sf -X PUT "$API/providers/proxies/$name" -w "  HTTP %{http_code}\n"
  done
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
    for name in $stale; do
      echo "all nodes dead for provider '$name' and last refresh older than 1h, refreshing subscription"
      curl -sf -X PUT "$API/providers/proxies/$name" -w "  HTTP %{http_code}\n" || true
    done
  else
    echo "no refresh needed"
  fi
  ;;
*)
  echo "usage: mihomo-ctl {status|providers|nodes|current|test|set-node \"NAME\"|refresh|refresh-if-dead}" >&2
  exit 1
  ;;
esac
