{
  stdenvNoCC,
  lib,
  nodejs,
  esbuild,
  source,
  pixel-node,
  agent-browser,
  zenbu-electron,
  hostPlatform,
  # Darwin only (lazy, never evaluated on Linux):
  swift,
  apple-sdk,
  "re-plistbuddy",
}:

# Assembles the terminal-browser dist tree, mirroring scripts/release.sh.
#
# Layout (mirrors the published tarball, with $out as the root):
#   bin/terminal-browser          wrapper: runs the electron dist as node
#   cli/dist/main.js             esbuild bundle of the cli
#   browser/dist/main.js         esbuild bundle of the browser
#   browser/native/pixel.node    rust engine native module
#   electron/                    the zenbu electron dist (or .app on darwin)
#   agent-browser/bin/agent-browser
#   assets/fonts/  scripts/  skills/
#   VERSION  CHANNEL
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "terminal-browser";
  version = source.shortRev;

  inherit (source) src;

  nativeBuildInputs = [ nodejs esbuild ]
    ++ lib.optionals hostPlatform.isDarwin [ swift apple-sdk re-plistbuddy ];

  buildInputs = [
    pixel-node
    agent-browser
    zenbu-electron
  ];

  # No configure/build phase: everything is done in installPhase so the
  # derivation mirrors scripts/release.sh step by step.
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    set -e

    mkdir -p $out/{bin,cli/dist,browser/dist,browser/native,agent-browser/bin,assets/fonts,scripts,skills}

    # rust engine native module (cdylib, renamed to pixel.node)
    cp ${pixel-node}/lib/libpixel_node.${lib.optionalString hostPlatform.isDarwin "dylib" "so"} \
      $out/browser/native/pixel.node

    # agent-browser native cli
    cp ${agent-browser}/bin/agent-browser $out/agent-browser/bin/agent-browser

    # bundle cli and browser with esbuild (same flags as scripts/bundle.sh)
    bundle() {
      ${esbuild}/bin/esbuild "$1" \
        --bundle --platform=node --format=cjs \
        --external:electron "--external:*.node" \
        "--alias:pixel-react=$PWD/engine/packages/pixel-react/src/index.ts" \
        "--alias:pixel-terminals=$PWD/terminals/src/index.ts" \
        "--alias:pixel-store=$PWD/store/src/index.ts" \
        "--define:process.env.NODE_ENV=\"production\"" \
        --sourcemap --outfile "$2" --log-level=warning
      printf '{"type":"commonjs"}\n' > "$(dirname "$2")/package.json"
    }
    bundle "$PWD/cli/src/main.ts" "$out/cli/dist/main.js"
    bundle "$PWD/browser/src/main.tsx" "$out/browser/dist/main.js"

    # generate the agent skills (scripts/generate-skill.sh calls
    # node_modules/.bin/esbuild, so point it at the esbuild binary)
    mkdir -p node_modules/.bin
    ln -s ${esbuild}/bin/esbuild node_modules/.bin/esbuild
    bash scripts/generate-skill.sh
    cp -R skill/build $out/skills

    # electron dist
    mkdir -p $out/electron
    ${lib.optionalString hostPlatform.isLinux ''
      cp -a ${zenbu-electron}/. $out/electron/
    ''}
    ${lib.optionalString hostPlatform.isDarwin ''
      # the engine bakes in a path to its build directory, so the swift helper
      # is compiled on the target host (same as scripts/release.sh)
      ${swift}/bin/swiftc -O -target arm64-apple-macos11 \
        engine/crates/pixel-core/native-scroll-helper.swift \
        -o $out/bin/native-scroll-helper
      codesign --force --sign - --timestamp=none $out/bin/native-scroll-helper || true
      codesign --force --sign - --timestamp=none $out/agent-browser/bin/agent-browser || true

      cp -a ${zenbu-electron}/Electron.app $out/electron/terminal-browser.app
      mv $out/electron/terminal-browser.app/Contents/MacOS/Electron \
         $out/electron/terminal-browser.app/Contents/MacOS/terminal-browser
      ${lib.getExe' re-plistbuddy "PlistBuddy"} \
        -c "Set :CFBundleExecutable terminal-browser" \
        -c "Set :CFBundleName terminal-browser" \
        -c "Set :CFBundleDisplayName terminal-browser" \
        -c "Set :CFBundleIdentifier dev.zenbu.terminal-browser" \
        $out/electron/terminal-browser.app/Contents/Info.plist
      codesign --force --sign - --timestamp=none $out/electron/terminal-browser.app
    ''}

    # support files
    cp scripts/apparmor.sh $out/scripts/apparmor.sh
    cp assets/fonts/JetBrainsMono-Regular.ttf $out/assets/fonts/

    # launcher wrapper (same as scripts/release.sh generates)
    ${lib.optionalString hostPlatform.isLinux ''
      cat > $out/bin/terminal-browser <<'WRAPPER'
      #!/bin/sh
      ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)"
      export TERMINAL_BROWSER_DIST_ROOT="$ROOT"
      export ELECTRON_RUN_AS_NODE=1
      exec "$ROOT/electron/electron" "$ROOT/cli/dist/main.js" "$@"
      WRAPPER
    ''}
    ${lib.optionalString hostPlatform.isDarwin ''
      cat > $out/bin/terminal-browser <<'WRAPPER'
      #!/bin/sh
      ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)"
      export TERMINAL_BROWSER_DIST_ROOT="$ROOT"
      export ELECTRON_RUN_AS_NODE=1
      export NATIVE_SCROLL_HELPER="\${NATIVE_SCROLL_HELPER:-$ROOT/bin/native-scroll-helper}"
      exec "$ROOT/electron/terminal-browser.app/Contents/MacOS/terminal-browser" "$ROOT/cli/dist/main.js" "$@"
      WRAPPER
    ''}
    chmod +x $out/bin/terminal-browser

    # what the dist reports itself as (scripts/upgrade.ts reads these)
    echo "main-${source.shortRev}" > $out/VERSION
    echo "dev" > $out/CHANNEL
  '';

  meta = {
    description = "A real browser that runs inside your terminal";
    homepage = "https://github.com/zenbu-labs/terminal-browser";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" "aarch64-darwin" ];
    mainProgram = "terminal-browser";
    # the electron dist is a prebuilt binary
    sourceProvenance = [ lib.sourceTypes.binaryCode ];
  };

  passthru = {
    inherit source pixel-node agent-browser zenbu-electron;
  };
})
