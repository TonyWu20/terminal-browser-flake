{
  rustPlatform,
  fetchgit,
  lib,
}:

# The agent-browser native CLI that terminal-browser ships in
# agent-browser/bin/agent-browser. It is the rust binary in the cli/
# subdirectory of the vercel-labs/agent-browser repo at tag v0.33.0.
let
  rev = "1ed371f3af472cc0d6cd8fdaea75d1a085ff7534"; # tag v0.33.0
in
rustPlatform.buildRustPackage {
  pname = "agent-browser";
  version = "0.33.0";

  src = fetchgit {
    url = "https://github.com/vercel-labs/agent-browser";
    inherit rev;
    hash = "sha256-TODO";
  };

  # The crate lives in the cli/ subdirectory of the repo.
  cargoRoot = "cli";
  buildAndTestSubdir = "cli";

  # The lock file is copied into this flake at the pinned revision.
  cargoLock = {
    lockFileContents = builtins.readFile ./agent-browser/Cargo.lock;
  };

  doCheck = false;

  meta = {
    description = "Browser automation CLI for AI agents, shipped by terminal-browser";
    homepage = "https://github.com/vercel-labs/agent-browser";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" "aarch64-darwin" ];
    mainProgram = "agent-browser";
  };
}
