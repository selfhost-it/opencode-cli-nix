#!/usr/bin/env bash
# update.sh — Automatically update OpenCode to the latest upstream release
# using Claude Code in non-interactive mode.
#
# Prerequisites:
#   - claude CLI installed and on PATH
#   - One-time acceptance of --dangerously-skip-permissions
#     (run: claude --dangerously-skip-permissions  and then /exit)
#
# Usage:
#   ./update.sh            # run the update
#   ./update.sh --dry-run  # print the command without executing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROMPT='Update opencode-cli-nix to the latest upstream release. Follow these steps:

1. Check the latest release using: curl -s https://api.github.com/repos/anomalyco/opencode/releases/latest | jq -r '.tag_name' (do NOT use gh, it may not be authenticated)
2. Compare with the current version in `package.nix` — if already up to date, stop
3. Update `package.nix`:
   a. Set the new `version`
   b. Fetch the new source `hash`:
      nix-prefetch-url --unpack --type sha256 https://github.com/anomalyco/opencode/archive/refs/tags/v<VERSION>.tar.gz
      nix hash convert --hash-algo sha256 --to sri <HASH>
   c. Update the `modelsDevApi` hash (set to "" and build — nix will show the correct hash)
   d. Update node_modules hashes in `hashes.json` (set to "" and build — nix will show the correct hash for the current platform)
4. Run `nix build .` to verify the build works
5. Verify: `./result/bin/opencode --version`
6. Scan all tracked files for passwords, tokens, API keys, private keys, or any sensitive/personal information — abort if anything is found
7. Commit with message: "Update OpenCode to v<VERSION>"
8. Push to origin/main'

if [[ "${1:-}" == "--dry-run" ]]; then
    echo "Would run:"
    echo "  cd $SCRIPT_DIR"
    echo "  claude -p <prompt> --dangerously-skip-permissions"
    exit 0
fi

cd "$SCRIPT_DIR"
claude -p "$PROMPT" --dangerously-skip-permissions
