#!/usr/bin/env bash
# Control helper for the headless mihomo (Clash Meta) proxy service on the
# Steam Deck. Installed to ~/.local/bin/mihomo-ctl by home-manager (see
# home/yiyiwang-steamdeck-home.nix). See README.md "Mihomo on Steam Deck".
#
# Usage:
#   mihomo-ctl status             Provider summary + node health (UP/DOWN, last delay)
#   mihomo-ctl nodes              Just the node list (UP/DOWN)
#   mihomo-ctl test               Live latency of every node (5s timeout each)
#   mihomo-ctl set-node "NAME"    Manually pick a node for the PROXY group
#   mihomo-ctl refresh            Force a subscription refresh now
#   mihomo-ctl refresh-if-dead    Refresh only when every node is dead and the last
#                                 refresh is older than 1h (used by the systemd timer)
#
# Named mihomo-ctl (not mihomo) because `mihomo` is the Clash Meta binary
# itself, installed by nixpkgs into ~/.nix-profile/bin ahead of ~/.local/bin
# on PATH.
#
# The Clash API listens on 127.0.0.1:9090 (external-controller in the mihomo
# config). Override with MIHOMO_API / MIHOMO_PROVIDER / MIHOMO_GROUP.
set -euo pipefail

API="${MIHOMO_API:-http://127.0.0.1:9090}"
PROVIDER="${MIHOMO_PROVIDER:-jms}"
GROUP="${MIHOMO_GROUP:-PROXY}"
PY="$(command -v python3 || echo /usr/bin/python3)"

case "${1:-}" in
status)
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT
  curl -sf "$API/providers/proxies/$PROVIDER" > "$tmp"
  "$PY" - "$tmp" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
proxies = d.get("proxies", [])
print(f"provider: {d.get('name')}  updatedAt: {d.get('updatedAt')}")
print(f"nodes: {len(proxies)}  alive: {sum(1 for p in proxies if p.get('alive'))}")
for p in proxies:
    last = "n/a"
    hist = p.get("history") or []
    if hist:
        last = f"{hist[-1].get('delay')}ms"
    mark = "UP  " if p.get("alive") else "DOWN"
    print(f"  {mark} {p.get('name')}  {last}")
PY
  ;;
nodes)
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT
  curl -sf "$API/providers/proxies/$PROVIDER" > "$tmp"
  "$PY" - "$tmp" <<'PY'
import json, sys
for p in json.load(open(sys.argv[1])).get("proxies", []):
    mark = "UP  " if p.get("alive") else "DOWN"
    print(f"{mark} {p.get('name')}")
PY
  ;;
test)
  "$PY" - "$API" "$PROVIDER" <<'PY'
import json, sys, urllib.parse, urllib.request
api, provider = sys.argv[1], sys.argv[2]
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
d = json.load(opener.open(f"{api}/providers/proxies/{provider}", timeout=10))
for p in d.get("proxies", []):
    name = p.get("name")
    url = f"{api}/providers/proxies/{provider}/{urllib.parse.quote(name, safe='')}/healthcheck?timeout=5000&url=http://www.gstatic.com/generate_204"
    try:
        r = json.load(opener.open(url, timeout=10))
        print(f"{name} -> {r.get('delay')}ms")
    except Exception:
        print(f"{name} -> FAIL")
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
  curl -sf -X PUT "$API/providers/proxies/$PROVIDER" -w "refresh: HTTP %{http_code}\n"
  ;;
refresh-if-dead)
  # exit 0 -> no refresh needed, exit 1 -> refresh
  if "$PY" - "$API" "$PROVIDER" <<'PY'; then
import json, sys, urllib.request, datetime
api, provider = sys.argv[1], sys.argv[2]
try:
    d = json.load(urllib.request.urlopen(f"{api}/providers/proxies/{provider}", timeout=10))
except Exception:
    sys.exit(0)  # API unreachable (mihomo starting/restarting) -> skip
proxies = d.get("proxies", [])
if proxies and any(p.get("alive") for p in proxies):
    sys.exit(0)
try:
    updated = datetime.datetime.fromisoformat(d["updatedAt"].replace("Z", "+00:00"))
    age = (datetime.datetime.now(updated.tzinfo) - updated).total_seconds()
except Exception:
    age = float("inf")
sys.exit(0 if age <= 3600 else 1)
PY
    echo "no refresh needed"
  else
    echo "all nodes dead and last refresh older than 1h, refreshing subscription"
    curl -sf -X PUT "$API/providers/proxies/$PROVIDER" -w "refresh: HTTP %{http_code}\n" || true
  fi
  ;;
*)
  echo "usage: mihomo-ctl {status|nodes|test|set-node \"NAME\"|refresh|refresh-if-dead}" >&2
  exit 1
  ;;
esac
