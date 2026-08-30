{
  stdenvNoCC,
  lib,
  fetchurl,
  unzip,
  # hostPlatform is read from stdenvNoCC (hostPlatform was removed from top level)
}: 

# The electron distribution that terminal-browser runs.
#
# terminal-browser refuses to start with any electron that is not the
# zenbu-labs fork (see scripts/fetch-electron.sh). This fetches the exact
# zip the release script would download, with the checksum from the
# mirror SHASUMS256.txt at v43.3.0.
let
  inherit (stdenvNoCC) hostPlatform;

  electronVersion = "43.3.0";

  platform =
    if hostPlatform.isDarwin then "darwin-arm64" else "linux-x64";

  # Verified against
  # https://github.com/zenbu-labs/electron-releases/releases/download/v43.3.0/SHASUMS256.txt
  # Upstream can re-publish the release assets of a fixed tag. When that
  # happens, the download bytes change and this pin must be refreshed.
  # (The darwin zips of v43.3.0 were re-published on 2026-08-30.)
  sha256 = (
    {
      linux-x64 = "cda5b298b9450c9b9a080dddf3b79fb7f15a8cd01e6de8fe4b26a19d12ef892f";
      darwin-arm64 = "92373642b9c425e004ee99cbd95f555da4885ca9e619a7013194fead56e4a987";
    }
  )."${platform}";
in
stdenvNoCC.mkDerivation {
  pname = "zenbu-electron";
  version = electronVersion;

  src = fetchurl {
    url = "https://github.com/zenbu-labs/electron-releases/releases/download/v${electronVersion}/electron-v${electronVersion}-${platform}.zip";
    inherit sha256;
  };

  nativeBuildInputs = [ unzip ];

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out
    unzip -q $src -d $out
    [ "$(cat $out/version)" = "${electronVersion}" ]
  '';

  meta = {
    description = "zenbu-labs electron fork, used by terminal-browser as its runtime";
    homepage = "https://github.com/zenbu-labs/electron-releases";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryCode ];
  };
}
