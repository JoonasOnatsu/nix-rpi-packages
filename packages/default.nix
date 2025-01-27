# https://nix.dev/tutorials/callpackage#interdependent-package-sets
{pkgs, ...}: let
  callPackage = pkgs.lib.callPackageWith (pkgs // packages);
  packages = {
    libpisp = callPackage ./libpisp {};
    libcamera = callPackage ./libcamera {};
    rpicam-apps = callPackage ./rpicam-apps {};
    raspberrypi-wireless-firmware = callPackage ./raspberrypi-wireless-firmware {};
    #rpi-kernel = callPackage ./rpi-kernel {inherit platforms;};
    #dtmerger = callPackage ./dtmerger.nix {};
  };
in
  packages
