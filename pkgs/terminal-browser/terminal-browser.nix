{
  stdenvNoCC,
  lib,
  nodejs,
  pnpm_10,
  pnpmConfigHook,
  makeBinaryWrapper,
  bash,
  source,
  pixel-node,
  agent-browser,
  zenbu-electron,
  pnpm-deps,
  # Darwin only; never evaluated on Linux.
  swift ? null,
  apple-sdk ? null,
  re-plistbuddy ? null,
  # Linux only; never evaluated on Darwin.
  glib ? null,
  nss ? null,
  nspr ? null,
  at-spi2-core ? null,
  cups ? null,
  dbus ? null,
  cairo ? null,
  gtk3 ? null,
  pango ? null,
  expat ? null,
  libxcb ? null,
  xkbcommon ? null,
  udev ? null,
  alsa-lib ? null,
  icu ? null,
  libgbm ? null,
  libX11 ? null,
  libXcomposite ? null,
  libXdamage ? null,
  libXext ? null,
  libXfixes ? null,
  libXrandr ? null,
  gcc-unwrapped ? null,
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
let
  inherit (stdenvNoCC) hostPlatform;

  # The electron dist is a prebuilt binary. It links against the usual
  # desktop runtime libraries. The launcher wrapper adds them to
  # LD_LIBRARY_PATH so the app runs on systems without a system profile
  # (for example NixOS). The upstream installer lists the same set.
  electronRuntimeLibs = lib.optionalAttrs hostPlatform.isLinux ([
    glib # glib-2.0, gobject-2.0, gio-2.0
    nss # nss3, nssutil3, smime3
    nspr # nspr4
    at-spi2-core # atk-1.0, atk-bridge-2.0, atspi
    cups
    dbus
    cairo
    gtk3 # gtk-3, gdk-3
    pango
    expat
    libxcb
    xkbcommon
    udev # libudev
    alsa-lib
    icu
    libgbm
    libX11
    libXcomposite
    libXdamage
    libXext
    libXfixes
    libXrandr
    gcc-unwrapped # libstdc++
  ]);

in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "terminal-browser";
  version = source.shortRev;

  inherit (source) src;

  nativeBuildInputs = [ nodejs pnpm_10 pnpmConfigHook ]
    ++ lib.optionals hostPlatform.isDarwin [ swift apple-sdk re-plistbuddy ]
    ++ lib.optionals hostPlatform.isLinux [ makeBinaryWrapper ];

  buildInputs = [
    pixel-node
    agent-browser
    zenbu-electron
  ];

  # Materialize node_modules from the pnpm store, like the release pipeline.
  pnpmDeps = pnpm-deps;

  # The pnpm config hook (post-configure) materializes node_modules from
  # the pnpm store. The build phase is unused: installPhase does everything,
  # mirroring scripts/release.sh step by step.
  dontBuild = true;

  installPhase = ''
    set -e

    # The repo scripts use a /bin/bash shebang, which the build sandbox
    # does not have. Point them at the build bash instead.
    substituteInPlace scripts/*.sh --replace-fail "#!/bin/bash" "#!${bash}/bin/bash"

    mkdir -p $out/{bin,cli/dist,browser/dist,browser/native,agent-browser/bin,assets/fonts,scripts,skills}

    # rust engine native module (cdylib, renamed to pixel.node)
    cp ${pixel-node}/lib/libpixel_node.${if hostPlatform.isDarwin then "dylib" else "so"} \
      $out/browser/native/pixel.node

    # agent-browser native cli
    cp ${agent-browser}/bin/agent-browser $out/agent-browser/bin/agent-browser

    # bundle cli and browser (scripts/bundle.sh runs node_modules/.bin/esbuild)
    bash scripts/bundle.sh "$PWD/cli/src/main.ts" "$out/cli/dist/main.js"
    bash scripts/bundle.sh "$PWD/browser/src/main.tsx" "$out/browser/dist/main.js"

    # generate the agent skills (same as scripts/release.sh)
    bash scripts/generate-skill.sh
    cp -R skill/build $out/skills

    # electron dist
    mkdir -p $out/electron
    ${lib.optionalString hostPlatform.isLinux ''
      cp -a ${zenbu-electron}/. $out/electron/
    ''}
    ${lib.optionalString hostPlatform.isDarwin ''
      # the engine bakes in a build-directory path, so the swift helper
      # compiles on the target host (same as scripts/release.sh)
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
      export NATIVE_SCROLL_HELPER="${"$"}{NATIVE_SCROLL_HELPER:-$ROOT/bin/native-scroll-helper}"
      exec "$ROOT/electron/terminal-browser.app/Contents/MacOS/terminal-browser" "$ROOT/cli/dist/main.js" "$@"
      WRAPPER
    ''}
    chmod +x $out/bin/terminal-browser

    # what the dist reports itself as (scripts/upgrade.ts reads these)
    echo "main-${source.shortRev}" > $out/VERSION
    echo "dev" > $out/CHANNEL
  '';

  # The electron dist is a prebuilt binary. The launcher wrapper points it at
  # the nix-provided runtime libraries (linux only; darwin uses system frameworks).
  postFixup = lib.optionalString hostPlatform.isLinux ''
    wrapProgram $out/bin/terminal-browser \
      --prefix LD_LIBRARY_PATH ":" "${lib.makeLibraryPath electronRuntimeLibs}"
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
    inherit source pixel-node agent-browser zenbu-electron pnpm-deps;
  };
})
