{
  description = "terminal-browser: a real browser that runs inside your terminal";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/8272fb3005b6d60897f4743f6e7d5a1e45f510cf";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-darwin" ];

      mkPackages = system:
        let
          attrs = import ./pkgs/terminal-browser/default.nix nixpkgs.legacyPackages.${system};
        in
        {
          default = attrs."terminal-browser";
          inherit (attrs)
            terminal-browser
            terminalBrowserPixelNode
            terminalBrowserAgentBrowser
            terminalBrowserZenbuElectron
            ;
        };
    in
    {
      # Adds terminal-browser (and its components) to a nixpkgs set.
      overlays.default = final: prev: import ./pkgs/terminal-browser/default.nix final;

      packages = nixpkgs.lib.genAttrs systems mkPackages;

      # Shell with the tools the upstream build pipeline uses (pnpm,
      # rust, node, unzip), for working on this package.
      devShells = nixpkgs.lib.genAttrs systems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.nodejs
              pkgs.pnpm_10
              pkgs.rustc
              pkgs.cargo
              pkgs.unzip
            ];
          };
        });

      # Smoke test: checks the dist layout and runs the cli bundle under
      # nix node. The cli bundle only uses node:* builtins, so no electron
      # binary is needed. This keeps the check sandbox-safe on both target
      # platforms.
      checks = nixpkgs.lib.genAttrs systems (system:
        let
          pkg = nixpkgs.legacyPackages.${system};
          tb = self.packages.${system}."terminal-browser";
        in
        {
          "terminal-browser" = pkg.stdenvNoCC.mkDerivation (finalAttrs: {
            pname = "terminal-browser-check";
            version = "0";
            buildInputs = [ tb ];
            nativeBuildInputs = [ pkg.nodejs ];
            dontUnpack = true;
            dontConfigure = true;
            dontBuild = true;
            installPhase = ''
              mkdir -p $out
              # The dist tree must match the release tarball layout.
              for f in "${tb}"/bin/terminal-browser "${tb}"/cli/dist/main.js "${tb}"/browser/dist/main.js "${tb}"/browser/native/pixel.node "${tb}"/agent-browser/bin/agent-browser "${tb}"/VERSION "${tb}"/CHANNEL; do
                [ -e "$f" ] || { echo "missing: $f" >&2; exit 1; }
              done
              # The launcher wrapper sets the dist root env var for the cli.
              export TERMINAL_BROWSER_DIST_ROOT="${tb}"
              node "${tb}"/cli/dist/main.js --version | grep -q "terminal-browser"
              # The unified user environment keeps only bin/. The launcher
              # must carry the embedded dist root for that case.
              grep -q "${tb}" "${tb}/bin/terminal-browser"
              ${nixpkgs.lib.optionalString (pkg.stdenv.hostPlatform.isDarwin) ''
                # darwin: the app links system frameworks, so the wrapper
                # runs standalone. Run it from a location without the dist
                # layout, as the unified user environment does.
                mkdir launcher-test
                cp "${tb}/bin/terminal-browser" launcher-test/terminal-browser
                sh launcher-test/terminal-browser --version | grep -q "terminal-browser"
              ''}
            '';
          });
        });
    };
}
