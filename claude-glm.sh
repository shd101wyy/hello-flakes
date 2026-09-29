#!/usr/bin/env bash
# claude-glm: run Claude Code against Zhipu GLM's Anthropic-compatible API
# (https://open.bigmodel.cn/api/anthropic), with its own config dir
# ~/.claude-glm (same pattern as the claude-rv / claude-sk aliases in
# home/common.nix). See README.md "claude-glm (Claude Code on GLM)".
#
# Secrets and overrides live in ~/.claude-glm.env, which is sourced AFTER
# the routing vars below are scrubbed from the calling shell and BEFORE the
# defaults are applied, so every default here can be overridden from that
# file. That file is yours alone — never managed by Nix. Minimal setup:
#
#   echo 'export ANTHROPIC_AUTH_TOKEN=your-zhipu-api-key' > ~/.claude-glm.env
#
#   claude-glm ARGS...   ==  claude ARGS... with the GLM env above
set -euo pipefail

env_file="$HOME/.claude-glm.env"

if [ ! -f "$env_file" ]; then
  echo "claude-glm: $env_file not found." >&2
  echo >&2
  echo "Create it with your Zhipu API key, e.g.:" >&2
  echo "  echo 'export ANTHROPIC_AUTH_TOKEN=xxx.xxx' > $env_file" >&2
  exit 1
fi

# It holds the API key — keep it private even if it was created with a lax
# umask (e.g. the README's `cat > ~/.claude-glm.env` under umask 022).
chmod 600 "$env_file"

# Scrub routing vars inherited from the calling shell: an ambient
# ANTHROPIC_BASE_URL would silently send the Zhipu token to another host,
# an ambient CLAUDE_CONFIG_DIR would write GLM state into another
# profile's config dir. The env file, sourced next, is the only override.
unset ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_BASE_URL \
  ANTHROPIC_MODEL ANTHROPIC_SMALL_FAST_MODEL \
  ANTHROPIC_DEFAULT_HAIKU_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL \
  ANTHROPIC_DEFAULT_OPUS_MODEL CLAUDE_CODE_AUTO_COMPACT_WINDOW \
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC API_TIMEOUT_MS CLAUDE_CONFIG_DIR

# shellcheck disable=SC1090
. "$env_file" || {
  echo "claude-glm: failed to source $env_file" >&2
  exit 1
}

if [ -z "${ANTHROPIC_AUTH_TOKEN:-}" ]; then
  echo "claude-glm: ANTHROPIC_AUTH_TOKEN is not set in $env_file" >&2
  echo >&2
  echo "Add your Zhipu API key to it, e.g.:" >&2
  echo "  echo 'export ANTHROPIC_AUTH_TOKEN=xxx.xxx' >> $env_file" >&2
  exit 1
fi
# `ANTHROPIC_AUTH_TOKEN=x` (without export) is an easy mistake in the env
# file; without this the check above would pass yet claude would still
# start without the token in its environment.
export ANTHROPIC_AUTH_TOKEN

export CLAUDE_CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude-glm}"
export ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL:-https://open.bigmodel.cn/api/anthropic}"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="${ANTHROPIC_DEFAULT_HAIKU_MODEL:-glm-5.3-flash[1m]}"
export ANTHROPIC_DEFAULT_SONNET_MODEL="${ANTHROPIC_DEFAULT_SONNET_MODEL:-glm-5.3[1m]}"
export ANTHROPIC_DEFAULT_OPUS_MODEL="${ANTHROPIC_DEFAULT_OPUS_MODEL:-glm-5.3[1m]}"
export CLAUDE_CODE_AUTO_COMPACT_WINDOW="${CLAUDE_CODE_AUTO_COMPACT_WINDOW:-800000}"
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="${CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC:-1}"
export API_TIMEOUT_MS="${API_TIMEOUT_MS:-3000000}"

if ! command -v claude >/dev/null 2>&1; then
  echo "claude-glm: 'claude' is not on PATH — install Claude Code first" >&2
  exit 1
fi

exec claude "$@"
