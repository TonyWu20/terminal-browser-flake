{
  rustPlatform,
  lib,
  source,
}:

# The pixel-node crate of the engine workspace.
# It is a napi cdylib that ships as browser/native/pixel.node.
#
# The engine is a cargo workspace in the engine/ subdirectory of the source.
rustPlatform.buildRustPackage {
  pname = "terminal-browser-pixel-node";
  version = "0.1.0";

  src = source.src;

  cargoRoot = "engine";
  buildAndTestSubdir = "engine";

  # The lock file is copied into this flake at the pinned source revision.
  cargoLock = {
    lockFileContents = builtins.readFile ./engine/Cargo.lock;
  };

  cargoBuildFlags = [ "-p" "pixel-node" ];

  doCheck = false;

  meta = {
    description = "Rust graphics engine of terminal-browser, built as a node native module";
    homepage = "https://github.com/zenbu-labs/terminal-browser";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" "aarch64-darwin" ];
  };
}
