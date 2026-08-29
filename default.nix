# Builds terminal-browser with the local nixpkgs.
# Use the flake (flake.nix) for packages and overlays.
{ nixpkgs ? import <nixpkgs> { } }:

(import ./pkgs/terminal-browser/default.nix nixpkgs)."terminal-browser"
