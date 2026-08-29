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
    };
}
