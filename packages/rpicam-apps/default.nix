# https://github.com/raspberrypi/rpicam-apps/tree/main
{
  stdenv,
  lib,
  fetchgit,
  meson,
  ninja,
  cmake,
  pkg-config,
  git,
  boost,
  libcamera,
  libpisp,
  libdrm,
  libjpeg,
  libexif,
  libpng,
  libtiff,
  python3,
  python3Packages,
  libavSupport ? true,
  ffmpeg, # libavSupport
  opencvSupport ? lib.meta.availableOn stdenv.hostPlatform opencv,
  opencv, # opencvSupport
  tfliteSupport ? false, #lib.meta.availableOn stdenv.hostPlatform tensorflow-lite,
  tensorflow-lite, # tfliteSupport
  qtSupport ? false,
  qt5, # qtSupport
  eglSupport ? false,
  xorg, # eglSupport
  libepoxy, # eglSupport
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "rpicam-apps";
  version = "1.5.2";

  src = with finalAttrs;
    fetchgit {
      url = "https://github.com/raspberrypi/rpicam-apps";
      rev = "v${version}";
      hash = "sha256-qCYGrcibOeGztxf+sd44lD6VAOGoUNwRqZDdAmcTa/U=";
    };

  strictDeps = true;

  outputs = [
    "out"
    "dev"
  ];

  postPatch = ''
    patchShebangs utils/
  '';

  nativeBuildInputs =
    [
      meson
      ninja
      cmake
      pkg-config
      python3
      git
    ]
    ++ (lib.optional qtSupport qt5.wrapQtAppsHook);

  buildInputs =
    [
      boost
      libcamera
      libpisp
      libdrm
      libjpeg
      libexif
      libpng
      libtiff
    ]
    ++ (lib.optionals libavSupport [
      ffmpeg
      ffmpeg.dev
    ])
    ++ (lib.optionals opencvSupport [
      opencv
    ])
    ++ (lib.optionals tfliteSupport [
      tensorflow-lite
    ])
    ++ (lib.optionals qtSupport [
      # QT preview
      qt5.qtbase
      qt5.qttools
    ])
    ++ (lib.optionals eglSupport [
      # EGL preview
      libepoxy
      xorg.libX11.dev
    ]);

  mesonFlags = [
    # TODO: download the models separately and
    # add them to the build
    (lib.mesonBool "download_hailo_models" false)
    (lib.mesonBool "download_imx500_models" false)
    (lib.mesonEnable "enable_drm" true)
    (lib.mesonEnable "enable_libav" libavSupport)
    (lib.mesonEnable "enable_opencv" opencvSupport)
    (lib.mesonEnable "enable_tflite" tfliteSupport)
    (lib.mesonEnable "enable_qt" qtSupport)
    (lib.mesonEnable "enable_egl" eglSupport)
    (lib.mesonEnable "enable_hailo" false)
  ];

  # Fixes error on a deprecated declaration
  env.NIX_CFLAGS_COMPILE = "-Wno-error=deprecated-declarations";

  meta = {
    description = "This is a small suite of libcamera-based applications to drive the cameras on a Raspberry Pi platform.";
    homepage = "https://github.com/raspberrypi/rpicam-apps";
    license = lib.licenses.bsd2;
    platforms = [
      "aarch64-linux"
      "armv6l-linux"
      "armv7l-linux"
    ];
  };
})
