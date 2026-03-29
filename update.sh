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

PROMPT=$(cat <<'EOF'
Update opencode-cli-nix to the latest upstream release.

1. Check the latest release:
   curl -s "https://api.github.com/repos/anomalyco/opencode/releases/latest" | jq -r '.tag_name'
   Do NOT use `gh`, it may not be authenticated.

2. Compare with the current `version` in `package.nix` — if already up to date, stop.

3. Update `package.nix`:
   a. Set `version` to the new value (without leading `v`).
   b. Set the source `hash = "";` -> run `nix build . 2>&1` -> find the line containing `got:` and extract the SRI hash (sha256-...=) -> update `hash`.
   c. Set the `modelsDevApi` `hash = "";` -> run `nix build . 2>&1` -> extract hash from `got:` -> update.

4. Update `hashes.json`:
   a. Set the nodeModules hash for the current platform (e.g. `x86_64-linux`) to `""`.
   b. Run `nix build . 2>&1` -> extract nodeModules hash from `got:` -> update `hashes.json`.

5. Run `nix build .` — this must succeed with no errors.

6. Verify: `./result/bin/opencode --version`

7. Scan all tracked files (`git ls-files`) for passwords, tokens, API keys, private keys, or sensitive information — abort if found. Content-addressable hashes are NOT secrets.

8. Commit: git add -A && git commit -m "Update OpenCode to v<VERSION>"

9. Push: GIT_SSH_COMMAND="ssh -i ~/.ssh/self-host-github" git push origin main
EOF
)

if [[ "${1:-}" == "--dry-run" ]]; then
    echo "Would run:"
    echo "  cd $SCRIPT_DIR"
    echo "  claude -p <prompt> --dangerously-skip-permissions"
    echo ""
    echo "Prompt:"
    echo "$PROMPT"
    exit 0
fi

cd "$SCRIPT_DIR"
exec claude -p "$PROMPT" --dangerously-skip-permissions
