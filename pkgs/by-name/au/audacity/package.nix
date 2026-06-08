{
  stdenv,
  lib,
  fetchFromGitHub,
  fetchzip,
  cmake,
  git,
  makeWrapper,
  wrapGAppsHook3,
  pkg-config,
  python3,
  gettext,
  file,
  libvorbis,
  libmad,
  libjack2,
  lv2,
  lilv,
  mpg123,
  opusfile,
  rapidjson,
  serd,
  sord,
  sqlite,
  sratom,
  suil,
  libsndfile,
  soxr,
  flac,
  lame,
  twolame,
  expat,
  libid3tag,
  libopus,
  libuuid,
  libtorch-bin,
  ffmpeg_7,
  opencl-clhpp,
  opencl-headers,
  ocl-icd,
  openvino,
  soundtouch,
  portaudio, # given up fighting their portaudio.patch?
  portmidi,
  linuxHeaders,
  alsa-lib,
  at-spi2-core,
  dbus,
  libepoxy,
  libxdmcp,
  libxtst,
  libpthread-stubs,
  libsbsms_2_3_0,
  libselinux,
  libsepol,
  libxkbcommon,
  util-linux,
  wavpack,
  wxwidgets_3_2,
  gtk3,
  libpng,
  libjpeg,
}:

# TODO
# 1. detach sbsms

let
  ffmpeg = ffmpeg_7;
  enableOpenVinoAi = stdenv.hostPlatform.isLinux && stdenv.hostPlatform.isx86_64;
  openvinoAudacityPluginSrc =
    if enableOpenVinoAi then
      fetchFromGitHub {
        owner = "intel";
        repo = "openvino-plugins-ai-audacity";
        tag = "v3.7.1-R4.2";
        hash = "sha256-nIW55AVMwttUdAK95GpYMrK3nQRK2yiDZm6ePiCLXI0=";
      }
    else
      null;
  openvinoWhisperMediumModels =
    if enableOpenVinoAi then
      fetchzip {
        url = "https://huggingface.co/Intel/whisper.cpp-openvino-models/resolve/main/ggml-medium-models.zip";
        hash = "sha256-W0FCbNmWeEp2XCbD6xkk2XjwdsvHW97Q45/ccBgO0sQ=";
        stripRoot = false;
      }
    else
      null;
  whisperCppOpenVino =
    if enableOpenVinoAi then
      stdenv.mkDerivation {
        pname = "whisper-cpp-openvino";
        version = "1.5.4";

        src = fetchFromGitHub {
          owner = "ggerganov";
          repo = "whisper.cpp";
          tag = "v1.5.4";
          hash = "sha256-9H2Mlua5zx2WNXbz2C5foxIteuBgeCNALdq5bWyhQCk=";
        };

        nativeBuildInputs = [
          cmake
          git
          pkg-config
        ];

        buildInputs = [ openvino ];

        cmakeFlags = [
          "-DBUILD_SHARED_LIBS=ON"
          "-DOpenVINO_DIR=${openvino}/runtime/cmake"
          "-DWHISPER_BUILD_EXAMPLES=OFF"
          "-DWHISPER_BUILD_TESTS=OFF"
          "-DWHISPER_OPENVINO=ON"
        ];

        installPhase = ''
          runHook preInstall
          cmake --install . --prefix $out
          runHook postInstall
        '';

        meta.platforms = [ "x86_64-linux" ];
      }
    else
      null;
  runtimeLibraries =
    [ ffmpeg ]
    ++ lib.optionals enableOpenVinoAi [
      libtorch-bin
      ocl-icd
      openvino
      whisperCppOpenVino
    ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "audacity";
  version = "3.7.7";

  src = fetchFromGitHub {
    owner = "audacity";
    repo = "audacity";
    rev = "Audacity-${finalAttrs.version}";
    hash = "sha256-UyQffN9vOSD3uDk4jpYGsjH577pU4V7FpFAu0xdsXUA=";
  };

  patches = [
    # Introduced by https://github.com/Tencent/rapidjson/commit/b1c0c2843fcb2aca9ecc650fc035c57ffc13697c#diff-2f1bcf2729ff7c408adb0c2cc2cfa01602bd5646b05b3e4bc7e46b606035d249R21
    ./rapidjson.patch
  ];

  postPatch = ''
    mkdir src/private
    substituteInPlace scripts/build/macOS/fix_bundle.py \
      --replace-fail "path.startswith('/usr/lib/')" "path.startswith('/usr/lib/') or path.startswith('${builtins.storeDir}')"
  ''
  + lib.optionalString stdenv.hostPlatform.isLinux ''
    substituteInPlace libraries/lib-files/FileNames.cpp \
      --replace-fail /usr/include/linux/magic.h ${linuxHeaders}/include/linux/magic.h
  ''
  + lib.optionalString enableOpenVinoAi ''
    cp -r ${openvinoAudacityPluginSrc}/mod-openvino modules/
    chmod -R u+w modules/mod-openvino
    substituteInPlace modules/mod-openvino/htdemucs.cpp \
      --replace-fail "float* pXTensor = x_tensor.data<float>();" "float* pXTensor = const_cast<float*>(x_tensor.data<float>());" \
      --replace-fail "float* pXTTensor = xt_tensor.data<float>();" "float* pXTTensor = const_cast<float*>(xt_tensor.data<float>());" \
      --replace-fail "float* pXTensor_Out = x_out_tensor.data<float>();" "float* pXTensor_Out = const_cast<float*>(x_out_tensor.data<float>());" \
      --replace-fail "float* pXTTensor_Out = xt_out_tensor.data<float>();" "float* pXTTensor_Out = const_cast<float*>(xt_out_tensor.data<float>());"
    sed -i '/^endforeach()/a \
\
add_subdirectory(mod-openvino)
' modules/CMakeLists.txt
  '';

  nativeBuildInputs = [
    cmake
    gettext
    pkg-config
    python3
    makeWrapper
    wrapGAppsHook3
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    linuxHeaders
  ];

  buildInputs = [
    expat
    ffmpeg
    file
    flac
    gtk3
    lame
    libid3tag
    libjack2
    libmad
    libopus
    libsbsms_2_3_0
    libsndfile
    libvorbis
    lilv
    lv2
    mpg123
    opusfile
    portmidi
    rapidjson
    serd
    sord
    soundtouch
    soxr
    sqlite
    sratom
    suil
    twolame
    portaudio
    wavpack
    wxwidgets_3_2
  ]
  ++ lib.optionals enableOpenVinoAi [
    libtorch-bin
    opencl-clhpp
    opencl-headers
    ocl-icd
    openvino
    whisperCppOpenVino
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    alsa-lib # for portaudio
    at-spi2-core
    dbus
    libepoxy
    libxdmcp
    libxtst
    libpthread-stubs
    libxkbcommon
    libselinux
    libsepol
    libuuid
    util-linux
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    libpng
    libjpeg
  ];

  cmakeFlags = [
    "-DAUDACITY_BUILD_LEVEL=2"
    "-DAUDACITY_REV_LONG=nixpkgs"
    "-DAUDACITY_REV_TIME=nixpkgs"
    "-DDISABLE_DYNAMIC_LOADING_FFMPEG=ON"
    "-Daudacity_conan_enabled=Off"
    "-Daudacity_use_ffmpeg=loaded"
    "-Daudacity_has_vst3=Off"
    "-Daudacity_has_crashreports=Off"

    # RPATH of binary /nix/store/.../bin/... contains a forbidden reference to /build/
    "-DCMAKE_SKIP_BUILD_RPATH=ON"

    # Fix duplicate store paths
    "-DCMAKE_INSTALL_LIBDIR=lib"
  ]
  ++ lib.optionals enableOpenVinoAi [
    "-DOpenVINO_DIR=${openvino}/runtime/cmake"
  ];

  preConfigure = lib.optionalString enableOpenVinoAi ''
    export LIBTORCH_ROOTDIR=${libtorch-bin.dev}
    export OpenVINO_DIR=${openvino}/runtime/cmake
    export WHISPERCPP_ROOTDIR=${whisperCppOpenVino}
  '';

  # [ 57%] Generating LightThemeAsCeeCode.h...
  # ../../utils/image-compiler: error while loading shared libraries:
  # lib-theme.so: cannot open shared object file: No such file or directory
  preBuild = ''
    export LD_LIBRARY_PATH=$PWD/Release/lib/audacity${lib.optionalString enableOpenVinoAi ":${lib.makeLibraryPath (lib.tail runtimeLibraries)}"}
  '';

  doCheck = false; # Test fails

  dontWrapGApps = true;

  postInstall = lib.optionalString enableOpenVinoAi ''
    mkdir -p "$out/share/audacity/openvino-models"
    cp -r ${openvinoWhisperMediumModels}/* "$out/share/audacity/openvino-models/"
  '';

  # Replace audacity's wrapper, to:
  # - Put it in the right place; it shouldn't be in "$out/audacity"
  # - Add the ffmpeg dynamic dependency
  # - Use Xwayland by default on Wayland. See https://github.com/audacity/audacity/pull/5977
  postFixup =
    lib.optionalString stdenv.hostPlatform.isLinux ''
      wrapProgram "$out/bin/audacity" \
        "''${gappsWrapperArgs[@]}" \
        --prefix LD_LIBRARY_PATH : "$out/lib/audacity":${lib.makeLibraryPath runtimeLibraries} \
        --suffix AUDACITY_MODULES_PATH : "$out/lib/audacity/modules" \
        --suffix AUDACITY_PATH : "$out/share/audacity" \
        --set-default GDK_BACKEND x11
    ''
    + lib.optionalString stdenv.hostPlatform.isDarwin ''
      mkdir -p $out/{Applications,bin}
      mv $out/Audacity.app $out/Applications/
      makeWrapper $out/Applications/Audacity.app/Contents/MacOS/Audacity $out/bin/audacity
    '';

  meta = {
    description = "Sound editor with graphical UI";
    mainProgram = "audacity";
    homepage = "https://www.audacityteam.org";
    changelog = "https://github.com/audacity/audacity/releases";
    license = with lib.licenses; [
      gpl2Plus
      # Must be GPL3 when building with "technologies that require it,
      # such as the VST3 audio plugin interface".
      # https://github.com/audacity/audacity/discussions/2142.
      gpl3
      # Documentation.
      cc-by-30
    ];
    maintainers = with lib.maintainers; [
      veprbl
      wegank
    ];
    platforms = lib.platforms.unix;
  };
})
