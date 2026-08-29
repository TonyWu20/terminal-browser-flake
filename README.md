# terminal-browser-flake

Packages [terminal-browser](https://github.com/zenbu-labs/terminal-browser) for
`x86_64-linux` and `aarch64-darwin`.

terminal-browser is a real browser that runs inside your terminal. It renders
chromium frames over the kitty graphics protocol and drives them with a rust
graphics engine. The package assembles the same dist tree the upstream
`scripts/release.sh` produces:

- `bin/terminal-browser` — launcher wrapper (runs the electron dist as node)
- `cli/dist/main.js`, `browser/dist/main.js` — esbuild bundles
- `browser/native/pixel.node` — rust engine built with cargo
- `electron/` — the zenbu-labs electron fork (the app refuses any other electron)
- `agent-browser/bin/agent-browser` — rust agent CLI
- `skills/`, `scripts/`, `assets/fonts/`, `VERSION`, `CHANNEL`

## Usage

```bash
# build the package
nix build .#x86_64-linux        # or .#aarch64-darwin on a mac
nix run .#x86_64-linux -- open https://terminal-browser.sh

# add it to a nix profile
nix profile add .#x86_64-linux

# use the overlay
# flake.nix:
#   inputs.terminal-browser.url = "github:<user>/terminal-browser-flake";
#   inputs.nixpkgs.overlays = [ terminal-browser.overlays.default ];
# then `pkgs.terminal-browser` in your configuration.
```

The overlay also exposes the components: `terminalBrowserPixelNode`,
`terminalBrowserAgentBrowser`, `terminalBrowserZenbuElectron`.

## Pins

| component | source |
| --- | --- |
| terminal-browser | commit `a1378a9` of [zenbu-labs/terminal-browser](https://github.com/zenbu-labs/terminal-browser) |
| agent-browser | tag `v0.33.0` (`1ed371f`) of [vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser) |
| electron | `43.3.0` from [zenbu-labs/electron-releases](https://github.com/zenbu-labs/electron-releases) |
| nixpkgs | commit `8272fb3` |

The cargo lock files of both rust projects are vendored in
`pkgs/terminal-browser/` and are verified against the fetched source at build
time.

## Notes

- The electron dist is a prebuilt binary, so on NixOS the runtime libraries it
  links (libnss3, gtk, ...) must come from your system profile, exactly as the
  upstream installer advises.
- On `aarch64-darwin` the build needs the `swift` compiler from nixpkgs
  (prebuilt on cache.nixos.org) plus the system `codesign` from the Xcode
  command line tools.
- Rebuild after `terminal-browser` moves on main: bump the `rev` in
  `pkgs/terminal-browser/source.nix`, refresh the `hash`, and refresh
  `pkgs/terminal-browser/engine/Cargo.lock` if the lock changed.
