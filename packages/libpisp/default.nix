# https://github.com/nix-community/raspberry-pi-nix
# https://github.com/sergei-mironov/nixos-raspi-camera/blob/main/nix/libpisp.nix
{
  stdenv,
  lib,
  fetchgit,
  meson,
  ninja,
  pkg-config,
  boost,
  nlohmann_json,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "libpisp";
  version = "1.0.7";

  src = with finalAttrs;
    fetchgit {
      url = "https://github.com/raspberrypi/libpisp";
      rev = "v${version}";
      hash = "sha256-Fo2UJmQHS855YSSKKmGrsQnJzXog1cdpkIOO72yYAM4=";
    };

  strictDeps = true;

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
  ];

  buildInputs = [
    boost
    nlohmann_json
  ];

  mesonFlags = [
    (lib.mesonEnable "logging" false)
  ];

  # Fixes error on a deprecated declaration
  env.NIX_CFLAGS_COMPILE = "-Wno-error=deprecated-declarations";

  meta = {
    description = "A helper library to generate run-time configuration for the Raspberry Pi ISP (PiSP), consisting of the Frontend and Backend hardware components.";
    homepage = "https://github.com/raspberrypi/libpisp";
    license = lib.licenses.bsd2;
    platforms = [
      "aarch64-linux"
      "armv6l-linux"
      "armv7l-linux"
    ];
  };
})
