#!/usr/bin/env bash
# dsh-tui: run the DeepSeek Harness (dsh) CLI with the cc-tui profile
# (dsh-TUI: https://github.com/ccch1mneyyy/dsh-TUI, npm package dsh-cc-tui).
# A thin wrapper over dsh-ctl (see dsh-ctl.sh / README.md "dsh-ctl").
#
#   dsh-tui ARGS...   ==  dsh-ctl exec --profile cc-tui ARGS...
#                         e.g. dsh-tui --help
#   dsh-tui update    Update the dsh-cc-tui plugin to its latest version
#                         ==  dsh-ctl exec plugin --profile cc-tui update dsh-cc-tui --latest
set -euo pipefail

case "${1:-}" in
update)
  exec dsh-ctl exec plugin --profile cc-tui update dsh-cc-tui --latest
  ;;
*)
  exec dsh-ctl exec --profile cc-tui "$@"
  ;;
esac
