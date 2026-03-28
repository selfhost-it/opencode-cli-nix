# opencode-cli-nix

Always up-to-date Nix package for [OpenCode](https://github.com/anomalyco/opencode) — the open source coding agent.

> **Beta**: This project is under active development by a solo maintainer and may break between updates. Use at your own risk. Contributions are welcome — feel free to open issues or submit pull requests!

## Why this package?

The OpenCode flake shipped in the upstream repo may lag behind releases or have build issues. This flake lets you:

1. **Always have the latest version** — update as soon as a new release drops
2. **Declarative installation** — managed in your NixOS or Home Manager config
3. **Reproducible builds** — built from source via Bun's `compile` feature

## Project Structure

| File | Purpose |
|---|---|
| `flake.nix` | Flake definition: inputs (nixpkgs, flake-utils), overlay, packages, app |
| `package.nix` | Build recipe: fetches the GitHub source, installs node_modules (FOD), compiles with Bun, wraps with ripgrep |
| `hashes.json` | Per-platform sha256 hashes for the node_modules fixed-output derivation |
| `flake.lock` | Pinned inputs |
| `.gitignore` | Excludes Nix build artifacts and editor files |

## Quick Start

```bash
# Run directly without installing
nix run github:selfhost-it/opencode-cli-nix

# Install to your profile
nix profile install github:selfhost-it/opencode-cli-nix
```

## NixOS / Home Manager Integration

### Add to your flake inputs

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    opencode = {
      url = "github:selfhost-it/opencode-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

### Apply the overlay

```nix
{
  nixpkgs.overlays = [
    opencode.overlays.default
  ];
}
```

### Add to your packages

NixOS (`configuration.nix`):

```nix
environment.systemPackages = with pkgs; [
  opencode
];
```

Home Manager (`home.nix`):

```nix
home.packages = with pkgs; [
  opencode
];
```

## Building Locally

```bash
git clone git@github.com:selfhost-it/opencode-cli-nix.git
cd opencode-cli-nix
nix build .

# Test
./result/bin/opencode --version

# Or run directly
nix run .
```

## Updating to a new OpenCode version

1. Change `version` in `package.nix` (e.g. `"1.4.0"`)

2. Update the source hash:
   ```bash
   nix-prefetch-url --unpack --type sha256 https://github.com/anomalyco/opencode/archive/refs/tags/v1.4.0.tar.gz
   nix hash convert --hash-algo sha256 --to sri <HASH>
   ```
   Copy the SRI hash into `package.nix`.

3. Set `modelsDevApi` hash to `""` in `package.nix` and run:
   ```bash
   nix build .
   ```
   The build will fail and print the correct hash. Paste it back.

4. Set the node_modules hash to `""` in `hashes.json` and run:
   ```bash
   nix build .
   ```
   The build will fail and print the correct hash. Paste it back.

5. Run `nix build .` again — it should succeed.

6. Commit and push.

Or run the automated update: `./update.sh`.

## Technical Details

- **Source**: Built from the [anomalyco/opencode](https://github.com/anomalyco/opencode) GitHub monorepo
- **Builder**: `bun install` (fixed-output derivation) + `Bun.build({ compile: true })`
- **Runtime**: Self-contained binary (Bun compiled), no Node.js or Bun needed at runtime
- **Runtime deps**: `ripgrep` (for code search, wrapped on PATH)
- **Binary**: `opencode` (at `$out/bin/opencode`)
- The build embeds a snapshot of the [models.dev](https://models.dev) API so opencode knows about available AI models without a runtime fetch
- The bun version check is patched to tolerate the nixpkgs bun version, which may lag slightly behind upstream requirements

## License

OpenCode is licensed under [MIT](https://github.com/anomalyco/opencode/blob/dev/LICENSE) by Anomaly.

---

Maintained by [self-host.it](https://self-host.it)
