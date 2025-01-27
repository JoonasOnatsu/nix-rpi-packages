{
  description = "Packages for Raspberry Pi";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    flake-utils,
    ...
  }: let
    systems = [
      "armv6l-linux"
      "armv7l-linux"
      "aarch64-linux"
    ];
    lib = nixpkgs.lib;

    out = system: let
      pkgs = import nixpkgs {
        inherit system;
        config = {};
        overlays = builtins.attrValues self.overlays;
      };
      appliedOverlay = self.overlays.default pkgs pkgs;
    in {
      packages = {
        inherit (appliedOverlay) libpisp libcamera rpicam-apps;
      };
    };
  in
    flake-utils.lib.eachSystem systems
    out
    // {
      overlays = {
        default = final: prev:
          import ./packages {
            pkgs = prev;
          };

        modifications = final: prev: {
          unbound = prev.unbound.overrideAttrs (
            finalAttrs: previousAttrs: {
              nativeBuildInputs = (previousAttrs.nativeBuildInputs or []) ++ [final.buildPackages.bison];
            }
          );

          # Pixman from stable 24.11 (v0.43.4) won't build
          # on armv6/armv7, but the version (v0.44.2) from
          # unstable builds, so make an override to change
          # the derivation to same as in unstable.
          pixman = prev.pixman.overrideAttrs (
            finalAttrs: previousAttrs: {
              version = "0.44.2";
              src = final.fetchurl {
                urls = with finalAttrs; [
                  "mirror://xorg/individual/lib/${pname}-${version}.tar.gz"
                  "https://cairographics.org/releases/${pname}-${version}.tar.gz"
                ];
                hash = "sha256-Y0kGHOGjOKtpUrkhlNGwN3RyJEII1H/yW++G/HGXNGY=";
              };
              mesonFlags = [];
            }
          );

          # Use the latest available firmware
          raspberrypifw = prev.raspberrypifw.overrideAttrs (
            finalAttrs: previousAttrs: {
              version = "1.20241126";
              src = final.fetchFromGitHub {
                owner = "raspberrypi";
                repo = "firmware";
                rev = finalAttrs.version;
                hash = "sha256-MCutxzdSFoZ4hn2Fxk2AHHgWCt/Jgc+reqJZHUuSKOc=";
              };
            }
          );
        };
      };
    };
}
