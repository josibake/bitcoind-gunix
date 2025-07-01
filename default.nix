{ pkgs ? import <nixpkgs> {} }:

let
  version = "5170ec1ae35d67923c5a4245cb4456aa2dd97385";
  url = "https://github.com/bitcoin/bitcoin/archive/${version}.tar.gz";
  sha256 = "sha256-fA1qL7OLafqK1fruve9mZYgAASoEvZe9hPCdf9Mx3eE";

  # try to bring in a custom compiler / toolchain
  nixpkgs-glibc231 = import (pkgs.fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "83162ab3b97d0e13b08e28938133381a7515c1e3";
    sha256 = "sha256-er5nJMIhpTaC7jv9KLuedVNttXvvUC28s2Rrhgd596Y=";
  }) {system = pkgs.system;};
  # pull out glibc and make sure its built with the same flags as guix
  glibc-2_31 = nixpkgs-glibc231.glibc.overrideAttrs (oldAttrs: {
    # Apply Bitcoin's security configuration flags (guix.scm lines 455-494)
    configureFlags =
      (oldAttrs.configureFlags or [])
      ++ [
        "--enable-stack-protector=all"
        "--enable-cet"
        "--enable-bind-now"
        "--disable-werror"
        "--disable-timezone-tools"
        "--disable-profile"
        "--build=${pkgs.stdenv.buildPlatform.config}"
      ];
  });

  base-gcc = pkgs.gcc13;
  gcc13-hardened = base-gcc.overrideAttrs (oldAttrs: {
    name = "gcc13-hardened";
    # Apply Bitcoin's GCC security flags (guix.scm lines 428-453)
    configureFlags =
      (oldAttrs.configureFlags or [])
      ++ [
        "--enable-initfini-array=yes"
        "--enable-default-ssp=yes"
        "--enable-default-pie=yes"
        "--enable-cet=yes"
        "--disable-gcov"
      ];
  });

  getCustomGccStdenv = customGcc: customGlibc: origStdenv: { pkgs, ... }:
  with pkgs; let
    compilerWrapped = wrapCCWith {
      cc = customGcc;
      bintools = wrapBintoolsWith {
        bintools = binutils-unwrapped;
        libc = customGlibc;
      };
    };
  in
    overrideCC origStdenv compilerWrapped;

  gcc_13_3_glibc_2_31 = getCustomGccStdenv
        gcc13-hardened glibc-2_31 pkgs.stdenv pkgs;
  depends = pkgs.callPackage ./depends.nix {
                inherit version url sha256;
                stdenv = gcc_13_3_glibc_2_31;
        };
  bitcoind = pkgs.callPackage ./bitcoind.nix {
                inherit url sha256 depends;
                stdenv = gcc_13_3_glibc_2_31;
        };
in {
  depends = depends;
  bitcoind = bitcoind;
}
