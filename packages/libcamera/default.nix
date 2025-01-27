# https://github.com/NixOS/nixpkgs/issues/305858
# https://github.com/RPi-Distro/libcamera/blob/pios/bookworm/debian/control
# https://github.com/NixOS/nixpkgs/blob/nixos-24.11/pkgs/by-name/li/libcamera/package.nix
# https://libcamera.org/getting-started.html
{
  stdenv,
  lib,
  fetchgit,
  meson,
  ninja,
  pkg-config,
  makeFontsConf,
  boost, # required
  python3, # required
  python3Packages, # required
  libyaml, # required
  libpisp, # PiSP pipeline
  gtest, # lc-compliance
  graphviz, # documentation
  doxygen, # documentation
  libevent, # for cam support
  libdrm, # for cam support
  libjpeg, # for cam support
  openssl, # IPA signing
  systemd, # for libudev
  enableGstreamer ? true,
  gst_all_1, # enableGstreamer
  enablePycamera ? true,
  enableTracing ? lib.meta.availableOn stdenv.hostPlatform lttng-ust,
  lttng-ust, # enableTracing
  enableQcam ? false,
  libtiff, # enableQcam
  qt6, # enableQcam
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "libcamera";
  version = "0.3.2+rpt20240927";
  src = with finalAttrs;
    fetchgit {
      url = "https://github.com/raspberrypi/libcamera";
      rev = "v${version}";
      hash = "sha256-TNNIOtitwFBlQx/2bcU7EeWvrMQAzEg/dS1skPJ8FMM=";
    };

  strictDeps = true;

  outputs = [
    "out"
    "dev"
  ];

  patches = [
    ./patches/0001_libcamera_installed.patch
    ./patches/0002_libcamera_fix_python_paths.patch
    ./patches/0003_ipc_no_timeout.patch
  ];

  postPatch = ''
    patchShebangs utils/
    patchShebangs src/py/
  '';

  # libcamera signs the IPA module libraries at install time, but they are then
  # modified by stripping and RPATH fixup. Therefore, we need to generate the
  # signatures again ourselves. For reproducibility, we use a static private key.
  #
  # If this is not done, libcamera will still try to load them, but it will
  # isolate them in separate processes, which can cause crashes for IPA modules
  # that are not designed for this (notably ipa_rpi.so).
  # https://github.com/RPi-Distro/libcamera/blob/pios/bookworm/utils/gen-ipa-priv-key.sh
  # https://github.com/RPi-Distro/libcamera/blob/pios/bookworm/src/ipa/ipa-sign-install.sh
  preBuild = ''
    ninja src/ipa-priv-key.pem
    install -D ${./ipa-priv-key.pem} src/ipa-priv-key.pem
  '';

  postFixup = ''
    ../src/ipa/ipa-sign-install.sh src/ipa-priv-key.pem $out/lib/libcamera/ipa_*.so
  '';

  nativeBuildInputs =
    [
      meson
      ninja
      pkg-config
      openssl
      doxygen # documentation
      graphviz # documentation
      python3
    ]
    ++ (with python3Packages; [
      jinja2
      ply
      pyyaml
      sphinx # documentation
    ])
    ++ (lib.optional enableQcam qt6.wrapQtAppsHook);

  buildInputs =
    [
      boost
      libpisp

      # IPA and signing
      openssl

      # Cam integration
      libevent
      libdrm
      libjpeg

      # Hotplugging (udev)
      systemd.dev

      # yamlparser
      libyaml
    ]
    ++ (lib.optionals enableGstreamer [
      # Gstreamer integration
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base
    ])
    ++ (lib.optionals enablePycamera [
      # pycamera
      python3Packages.pybind11
    ])
    ++ (lib.optionals enableTracing [
      # lttng tracing
      lttng-ust
    ])
    ++ (lib.optionals enableQcam [
      # QCAM support
      libtiff
      qt6.qtbase
      qt6.qttools
    ]);

  mesonFlags = [
    "--buildtype=release"
    (lib.mesonBool "v4l2" true)
    (lib.mesonOption "pipelines" "auto")
    #(lib.mesonOption "pipelines" "rpi/vc4,rpi/pisp")
    #(lib.mesonOption "ipas" "rpi/vc4,rpi/pisp")
    (lib.mesonEnable "gstreamer" enableGstreamer)
    (lib.mesonEnable "pycamera" enablePycamera)
    (lib.mesonEnable "tracing" enableTracing)
    (lib.mesonEnable "qcam" enableQcam)
    # Tries to unconditionally download gtest when enabled
    "-Dlc-compliance=disabled"
    # Avoid blanket -Werror to evade build failures on less
    # tested compilers.
    "-Dwerror=false"
    # Documentation breaks binary compatibility.
    # Given that upstream also provides public documentation,
    # we can disable it here.
    "-Ddocumentation=disabled"
  ];

  # Fixes error on a deprecated declaration
  env.NIX_CFLAGS_COMPILE = "-Wno-error=deprecated-declarations";

  # Silence fontconfig warnings about missing config
  FONTCONFIG_FILE = makeFontsConf {fontDirectories = [];};

  meta = with lib; {
    description = "An open source camera stack and framework for Linux, Android, and ChromeOS";
    homepage = "https://libcamera.org";
    changelog = "https://github.com/raspberrypi/libcamera/releases/tag/${src.rev}";
    license = licenses.lgpl2Plus;
    maintainers = with maintainers; [citadelcore];
    badPlatforms = [
      # Mandatory shared libraries.
      lib.systems.inspect.platformPatterns.isStatic
    ];
  };
})
