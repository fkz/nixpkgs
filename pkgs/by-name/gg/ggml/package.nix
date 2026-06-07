{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  cmake,
  rocmPackages,
  python3,
  mkLLVMPackages
}:

let
  mlir-aie = python3.pkgs.buildPythonPackage rec {
    pname = "mlir-aie";
    version = "1.3.1";
    format = "wheel";

    src = fetchurl {
      url = "https://github.com/Xilinx/mlir-aie/releases/download/v${version}/mlir_aie-${version}-cp313-cp313-manylinux_2_35_x86_64.whl";
      hash = "sha256-SpdF11EbZ+WHEdqJACREsQPeX1+1JvjvMYh25tm5e04=";
    };

    dependencies = [
      python3.pkgs.cloudpickle
      python3.pkgs.numpy
    ];

    postInstall = ''
      ln -s "$out/${python3.sitePackages}/mlir_aie/python/aie" "$out/${python3.sitePackages}/aie"
    '';

    pythonImportsCheck = [ "aie" ];
  };

  hsaPythonEnv = python3.withPackages (ps: [
    mlir-aie
    ps.numpy
    ps.ml-dtypes
  ]);
in

stdenv.mkDerivation (finalAttrs: {
  pname = "ggml";
  version = "0.11.0";

  __structuredAttrs = true;
  strictDeps = true;

  src = fetchFromGitHub {
    owner = "fkz";
    repo = "ggml";
    rev = "88c9d21dc0bde8c5aa59228655ffb81b825df9ac";
    hash = "sha256-0vmv9qRr/FgO7Rd+NtYt8mhR+vbPHGafwQZ4itXr/gA=";
  };

  patches = [
    ./fix-hsa-backend-interface.patch
  ];

  # The cmake package does not handle absolute CMAKE_INSTALL_LIBDIR and CMAKE_INSTALL_INCLUDEDIR
  # correctly.
  # Tracking: https://github.com/NixOS/nixpkgs/issues/144170
  postPatch = ''
    substituteInPlace ggml.pc.in \
      --replace-fail \
        "\''${prefix}/@CMAKE_INSTALL_INCLUDEDIR@" \
        "@CMAKE_INSTALL_FULL_INCLUDEDIR@" \
      --replace-fail \
        "\''${prefix}/@CMAKE_INSTALL_LIBDIR@" \
        "@CMAKE_INSTALL_FULL_LIBDIR@"

    substituteInPlace src/ggml-hsa/aie-kernel-compiler.cpp \
      --replace-fail \
        'sys.attr("path").attr("append")(kernel_path.string());' \
        'sys.attr("path").attr("append")(kernel_path.string()); sys.attr("path").attr("append")("${hsaPythonEnv}/${python3.sitePackages}");'
  '';

  nativeBuildInputs = [
    cmake
    python3
  ];

  buildInputs = [
    python3
    rocmPackages.rocm-runtime
  ];

  cmakeFlags = [
    (lib.cmakeBool "GGML_HSA" true)
    (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_PYBIND11" "${python3.pkgs.pybind11.src}")
    (lib.cmakeFeature "hsa-runtime64_DIR" "${rocmPackages.rocm-runtime}/lib/cmake/hsa-runtime64")
  ];

  meta = {
    description = "Tensor library for machine learning";
    homepage = "https://github.com/ggml-org/ggml";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ GaetanLepage ];
    platforms = lib.platforms.all;
  };
})
