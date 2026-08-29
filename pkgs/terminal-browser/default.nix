# Builds terminal-browser and its components from pinned upstream revisions.
#
# Takes the nixpkgs attribute set and returns the attributes an overlay adds.
pkgs:

let
  source = pkgs.callPackage ./source.nix { };

  pixel-node = pkgs.callPackage ./pixel-node.nix {
    inherit source;
  };

  agent-browser = pkgs.callPackage ./agent-browser.nix { };

  zenbu-electron = pkgs.callPackage ./electron.nix { };

  # The pnpm store of the workspace, installed with the lock file.
  # The build materializes node_modules from it, exactly like the
  # release pipeline (pnpm install, then scripts/release.sh).
  pnpm-deps = pkgs.fetchPnpmDeps {
    pname = "terminal-browser";
    version = source.shortRev;
    src = source.src;
    pnpm = pkgs.pnpm_10;
    fetcherVersion = 4;
    hash = "sha256-lyN0LoFV24539lziw4rE3x9MxC5zFcRcFlS25+fniOU=";
  };

  terminal-browser = pkgs.callPackage ./terminal-browser.nix {
    inherit source pixel-node agent-browser zenbu-electron;
    pnpm-deps = pnpm-deps;
  };
in
{
  inherit terminal-browser;

  # the components of terminal-browser
  terminalBrowserPixelNode = pixel-node;
  terminalBrowserAgentBrowser = agent-browser;
  terminalBrowserZenbuElectron = zenbu-electron;
  terminalBrowserPnpmDeps = pnpm-deps;
}
