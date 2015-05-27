{stdenv, fetchurl, libtool, libjpeg, xz, xlibs, zlib, mesa, glib, gstreamer, libxml2 
, cups, sqlite, expat, gst_plugins_base, qt5, fontconfig, freetype, which, cdrkit
, makeWrapper, perl, wget, ncurses, xdg_utils, unzip, less}:

let 
  libtiff = import ./libtiff4.nix { inherit stdenv fetchurl zlib libjpeg; };
  rpath = stdenv.lib.makeSearchPath "lib" [ 
    stdenv.glibc libtool xlibs.libX11 xlibs.libXrender xlibs.libSM xlibs.libICE
    xlibs.libxcb cups zlib mesa glib gstreamer gst_plugins_base libxml2
    sqlite expat qt5.base qt5.tools qt5.svg qt5.declarative qt5.graphicaleffects 
    qt5.quickcontrols qt5.webkit libtiff fontconfig freetype
  ] + ":${stdenv.cc.cc}/lib64"; in

stdenv.mkDerivation {
  name = "cewe-fotobuch";
  version = "6.0.3";
  buildInputs = [makeWrapper wget ncurses which xdg_utils unzip less];
  src = fetchurl {
    url = http://dls.photoprintit.de/download/Data/16523/hps/setup_Mein_CEWE_FOTOBUCH.tgz;
    sha256 = "0blxp3x9dq6b9iqlkz5gz67xbg8351m8axi6zgs3grxk7a5i44lc";
  };
  sourceRoot = "";
  installPhase = ''
    yes ja | ${perl}/bin/perl install.pl -i $out || true
    rm $out/libQt5*
    rm -r $out/platforms
    IFS=$(echo -en "\n\b")
    for file in $(find $out -type f); do
      patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$file" || true
      patchelf --set-rpath ${rpath}:\$ORIGIN "$file" || true
    done
    makeWrapper "$out/Mein\ CEWE\ FOTOBUCH" $out/bin/cewe-fotobuch \
      --prefix PATH : ${which}/bin:${cdrkit}/bin \
      --set QT_QPA_PLATFORM_PLUGIN_PATH ${qt5.base}/lib/qt5/plugins
   '';
  meta = with stdenv.lib; {
    description = "an offline client for creating photobooks, uploading and ordering them at cewe.de";
    homepage = http://www.cewe-fotobuch.de;
    license = licenses.unfree;
    platforms = ["x86_64-linux"];
    maintainers = with maintainers; [ schmitthenner ];
   };
}
