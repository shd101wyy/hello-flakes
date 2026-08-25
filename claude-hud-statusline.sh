#!/usr/bin/env bash
# claude-hud statusline launcher.
# Resolves the plugin dir and a node binary at runtime so neither a plugin
# version bump nor a garbage-collected nix store path can break the HUD.

# --- terminal width -------------------------------------------------------
cols=${COLUMNS:-}
case "$cols" in
  ""|*[!0-9]*) cols=$( { stty size </dev/tty | awk '{print $2}'; } 2>/dev/null ) ;;
esac
case "$cols" in
  ""|*[!0-9]*) cols=120 ;;
esac
export COLUMNS=$(( cols > 4 ? cols - 4 : 1 ))

# --- newest installed claude-hud ------------------------------------------
config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
plugin_dir=$(ls -d "$config_dir"/plugins/cache/*/claude-hud/*/ 2>/dev/null \
  | awk -F/ '{ print $(NF-1) "\t" $0 }' \
  | grep -E '^[0-9]+\.[0-9]+\.[0-9]+[[:space:]]' \
  | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n \
  | tail -1 | cut -f2-)

if [ -z "$plugin_dir" ]; then
  echo "claude-hud: plugin not found under $config_dir/plugins/cache (try: claude plugin update claude-hud@claude-hud)"
  exit 0
fi

# --- runtime --------------------------------------------------------------
node_bin=$(command -v node 2>/dev/null)
if [ -z "$node_bin" ]; then
  for candidate in /opt/homebrew/bin/node "$HOME/.nix-profile/bin/node" /usr/local/bin/node /run/current-system/sw/bin/node; do
    if [ -x "$candidate" ]; then node_bin="$candidate"; break; fi
  done
fi

if [ -n "$node_bin" ] && [ -f "${plugin_dir}dist/index.js" ]; then
  exec "$node_bin" "${plugin_dir}dist/index.js"
fi

# Fallback: bun running the TypeScript source directly.
bun_bin=$(command -v bun 2>/dev/null)
if [ -z "$bun_bin" ]; then
  bun_bin=$(ls -d /nix/store/*-bun-*/bin/bun 2>/dev/null | tail -1)
fi
if [ -n "$bun_bin" ] && [ -f "${plugin_dir}src/index.ts" ]; then
  exec "$bun_bin" --env-file /dev/null "${plugin_dir}src/index.ts"
fi

echo "claude-hud: no node or bun runtime found on PATH"
