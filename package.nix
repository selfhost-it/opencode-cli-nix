# OpenCode - the open source coding agent
#
# Built from GitHub source using Bun's compile feature.
#
# To update:
#   1. Change `version`
#   2. Update `srcHash` (run: nix-prefetch-github anomalyco opencode --rev v<VERSION>)
#   3. Refresh `api.json`: curl -s "https://models.dev/api.json" -o api.json
#   4. Update node_modules hashes in `hashes.json` (set to "" and build for each platform)
#   5. If upstream requires a newer bun, bump `bunVersion` and update `bunHashes`
#   6. Run `nix build`

{ lib
, stdenvNoCC
, fetchFromGitHub
, fetchurl
, bun
, makeBinaryWrapper
, ripgrep
, installShellFiles
}:

let
  version = "1.4.10";

  src = fetchFromGitHub {
    owner = "anomalyco";
    repo = "opencode";
    rev = "v${version}";
    hash = "sha256-L2oiB7YwAaB07ZSEjxOUobX3fZW4noluUbo/FFPDYl4=";
  };

  # Snapshot of the models.dev API — vendored in the repo so the build is
  # fully reproducible and never breaks when upstream changes the file.
  # Refresh with: curl -s "https://models.dev/api.json" -o api.json
  modelsDevApi = ./api.json;

  platform = stdenvNoCC.hostPlatform;
  bunCpu = if platform.isAarch64 then "arm64" else "x64";
  bunOs = if platform.isLinux then "linux" else "darwin";

  # Pin bun to a version compatible with OpenCode, regardless of
  # what the user's nixpkgs provides (avoids "bun too old" errors
  # when the flake is consumed with `inputs.nixpkgs.follows`).
  bunVersion = "1.3.11";
  bunHashes = {
    "x86_64-linux"  = "sha256-hhG6k1r4hvBabzh0ChUWAybBXl1dB63vlmEwtEk2B+0=";
    "aarch64-linux"  = "sha256-0TlE2hKlPsx0v2pyC9HQTEVVwDjf5CI2U1anvkdpH98=";
    "aarch64-darwin" = "sha256-b1o0Z+2crsR5W/eM1HZQfZ+HDH1XuGyUX8szgSZ3L/w=";
    "x86_64-darwin"  = "sha256-+2c5sIv1RVDtqnyCTNWy3KRbagav70CEQwh6YxBfb40=";
  };
  bunPinned = bun.overrideAttrs (old: {
    version = bunVersion;
    src = fetchurl {
      url = "https://github.com/oven-sh/bun/releases/download/bun-v${bunVersion}/bun-${bunOs}-${bunCpu}${lib.optionalString (platform.isDarwin && platform.isx86_64) "-baseline"}.zip";
      hash = bunHashes.${platform.system};
    };
  });

  hashes = builtins.fromJSON (builtins.readFile ./hashes.json);

  # Fixed-output derivation: runs `bun install` with network access,
  # then the output is verified against a known hash.
  nodeModules = stdenvNoCC.mkDerivation {
    pname = "opencode-node-modules";
    inherit version src;

    nativeBuildInputs = [ bunPinned ];
    dontConfigure = true;

    buildPhase = ''
      runHook preBuild
      export HOME=$(mktemp -d)
      export BUN_INSTALL_CACHE_DIR=$(mktemp -d)
      bun install \
        --cpu="${bunCpu}" \
        --os="${bunOs}" \
        --filter '!./' \
        --filter './packages/opencode' \
        --filter './packages/desktop' \
        --frozen-lockfile \
        --ignore-scripts \
        --no-progress
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      find . -type d -name node_modules -exec cp -R --parents {} $out \;
      runHook postInstall
    '';

    dontFixup = true;
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = hashes.nodeModules.${platform.system};
  };

in
stdenvNoCC.mkDerivation {
  pname = "opencode";
  inherit version src;

  nativeBuildInputs = [
    bunPinned
    installShellFiles
    makeBinaryWrapper
  ];

  env = {
    MODELS_DEV_API_JSON = "${modelsDevApi}";
    OPENCODE_DISABLE_MODELS_FETCH = "true";
    OPENCODE_VERSION = version;
    OPENCODE_CHANNEL = "local";
  };

  configurePhase = ''
    runHook preConfigure
    cp -R ${nodeModules}/. .
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    export HOME=$(mktemp -d)
    pushd packages/opencode
    bun --bun ./script/build.ts --single --skip-install --skip-embed-web-ui
    bun --bun ./script/schema.ts schema.json
    popd
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 packages/opencode/dist/opencode-*/bin/opencode $out/bin/opencode
    install -Dm644 packages/opencode/schema.json $out/share/opencode/schema.json

    wrapProgram $out/bin/opencode \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]}

    runHook postInstall
  '';

  postInstall = lib.optionalString (stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform) ''
    installShellCompletion --cmd opencode \
      --bash <($out/bin/opencode completion) \
      --zsh <(SHELL=/bin/zsh $out/bin/opencode completion)
  '';

  meta = {
    description = "OpenCode - the open source coding agent";
    homepage = "https://opencode.ai/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
    mainProgram = "opencode";
  };
}
