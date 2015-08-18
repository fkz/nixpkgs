{ lib, stdenv, fetchFromGitHub, nix, readline, boehmgc }:

let rev = "57aeef0b6a3d3c9506e35f57f5b6db33019967e5"; in

stdenv.mkDerivation {
  name = "nix-repl-${lib.getVersion nix}-${lib.substring 0 7 rev}";

  src = fetchFromGitHub {
    owner = "edolstra";
    repo = "nix-repl";
    inherit rev;
    sha256 = "1p92zwkpy3iaglq23aydggbl6dbnw97f0v5gy2w74y8pi9d5mgh5";
  };

  buildInputs = [ nix readline ];

  buildPhase = "true";

  # FIXME: unfortunate cut&paste.
  installPhase =
    ''
      mkdir -p $out/bin
      $CXX -O3 -Wall -std=c++0x \
        -o $out/bin/nix-repl nix-repl.cc \
        -I${nix}/include/nix \
        -lnixformat -lnixutil -lnixstore -lnixexpr -lnixmain -lreadline -lgc \
        -DNIX_VERSION=\"${(builtins.parseDrvName nix.name).version}\"
    '';

  meta = {
    homepage = https://github.com/edolstra/nix-repl;
    description = "An interactive environment for evaluating and building Nix expressions";
    maintainers = [ lib.maintainers.eelco ];
    license = lib.licenses.gpl3;
    platforms = nix.meta.platforms;
  };
}
