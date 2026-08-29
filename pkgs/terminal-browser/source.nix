{ fetchgit, lib }:

# Pinned terminal-browser source.
#
# rev: commit on the main branch of https://github.com/zenbu-labs/terminal-browser.
let
  rev = "a1378a9bdf93fb1a617a1af2557c9fa5d3f0a14e";
in
{
  inherit rev;
  shortRev = lib.substring 0 7 rev;
  src = fetchgit {
    url = "https://github.com/zenbu-labs/terminal-browser";
    inherit rev;
    hash = "sha256-TODO";
  };
}
