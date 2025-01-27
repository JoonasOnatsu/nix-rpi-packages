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
    lib = nixpkgs.lib;

    buildTargets = {
      # Raspberry Pi 1/Zero/Zero W
      "armv6l-linux" = {
        config = "armv6l-unknown-linux-gnueabihf";
      };

      # Raspberry Pi 2
      "armv7l-linux" = {
        config = "armv7l-unknown-linux-gnueabihf";
      };

      # Raspberry Pi 3/4/Zero 2W
      "aarch64-linux" = {
        config = "aarch64-unknown-linux-gnu";
      };
    };

    # eachSystem [system] (system: ...)
    #
    # Returns an attrset with a key for every system in the given array, with
    # the key's value being the result of calling the callback with that key.
    eachSystem = systems: fn:
      builtins.foldl'
      (acc: system: acc // {${system} = fn system;})
      {}
      systems;

    mkPkgs = {
      localSystem ? {
        config = "x86_64-unknown-linux-gnu";
        system = "x86_64-linux";
      },
      crossSystem ? null,
      config ? {
        allowUnsupportedSystem = true;
        allowUnfree = true;
      },
      overlays ? [],
    }:
      import nixpkgs ({
          inherit localSystem config overlays;
        }
        // (
          if crossSystem == null
          then {}
          else {
            # The nixpkgs cache doesn't have any packages where cross-compiling has
            # been enabled, even if the target platform is actually the same as the
            # build platform (and therefore it's not really cross-compiling). So we
            # only set up the cross-compiling config if the target platform is
            # different.
            crossSystem = {
              system = "${crossSystem}";
              config = buildTargets.${crossSystem}.config;
            };
          }
        ));
  in {
    packages =
      eachSystem
      (builtins.attrNames buildTargets)
      (
        crossSystem: let
          pkgs = mkPkgs {
            inherit crossSystem;
            overlays = [
              (final: prev: {
                # Fix unbound not cross-compiling
                unbound = prev.unbound.overrideAttrs (
                  finalAttrs: previousAttrs: {
                    nativeBuildInputs = (previousAttrs.nativeBuildInputs or []) ++ [final.buildPackages.bison];
                  }
                );

                # Pixman from stable 24.11 (v0.43.4) won't build on armv6/armv7,
                # but the version (v0.44.2) works, so make an override to change
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
              })
            ];
          };
        in
          import ./packages {inherit pkgs;}
      );
  };
}
