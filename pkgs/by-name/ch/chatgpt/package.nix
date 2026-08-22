{
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  bubblewrap,
  buildFHSEnv,
  cairo,
  cups,
  dbus,
  dpkg,
  expat,
  fetchurl,
  gdk-pixbuf,
  glib,
  gtk3,
  lib,
  libdrm,
  libgbm,
  libGL,
  libnotify,
  libpulseaudio,
  libusb1,
  libx11,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  libxcb,
  mesa,
  nspr,
  nss,
  pango,
  ripgrep,
  stdenv,
  systemd,
}:
let
  version = "26.818.31338";
  src = fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_26.818.31338_amd64.deb";
    hash = "sha256-Q4J4SKdHJLVyvn+NyVRpirLMCRb3+dWZGg7oKJlE+Vs=";
  };

  unwrapped = stdenv.mkDerivation {
    pname = "chatgpt-unwrapped";
    inherit version src;
    dontUnpack = true;
    dontFixup = true;
    nativeBuildInputs = [ dpkg ];
    installPhase = "dpkg-deb --extract $src $out";
  };
in
buildFHSEnv {
  pname = "chatgpt";
  inherit version;

  targetPkgs = pkgs: [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    bubblewrap
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libgbm
    libGL
    libnotify
    libpulseaudio
    libusb1
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    libxcb
    mesa
    nspr
    nss
    pango
    ripgrep
    systemd
  ];

  extraBwrapArgs = [
    "--ro-bind ${unwrapped}/usr /opt"
  ];
  runScript = "/opt/bin/chatgpt";

  extraInstallCommands = ''
    cp -r ${unwrapped}/usr/share $out/share
  '';

  meta = {
    description = "OpenAI desktop app with Chat, Work, and Codex in an FHS environment";
    homepage = "https://chatgpt.com/download/";
    license = lib.licenses.unfree;
    mainProgram = "chatgpt";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
