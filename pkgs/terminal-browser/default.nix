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

  terminal-browser = pkgs.callPackage ./terminal-browser.nix {
    inherit source pixel-node agent-browser zenbu-electron;
  };
in
{
  inherit terminal-browser;

  # the components of terminal-browser
  terminalBrowserPixelNode = pixel-node;
  terminalBrowserAgentBrowser = agent-browser;
  terminalBrowserZenbuElectron = zenbu-electron;
}
