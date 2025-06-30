{ pkgs ? import <nixpkgs> {} }:

let
  version = "5170ec1ae35d67923c5a4245cb4456aa2dd97385";
  url = "https://github.com/bitcoin/bitcoin/archive/${version}.tar.gz";
  sha256 = "sha256-fA1qL7OLafqK1fruve9mZYgAASoEvZe9hPCdf9Mx3eE";

  # try to bring in a custom compiler / toolchain
  glibc_2_31 = (import (pkgs.fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "3913f6a514fa3eb29e34af744cc97d0b0f93c35c";
    sha256 = "sha256-TRATNxmc1sovxMAgcUYQAowAR+wxF4ZFoOOF7A80WiU";
  }) {}).glibc;

  gcc_13_3 = (import (pkgs.fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "882842d2a908700540d206baa79efb922ac1c33d";
    sha256 = "sha256-+HBffoSXLhuNJtjxHOZYIyY+PQirlwHKMrir+xIUu4A";
  }) {}).gcc-unwrapped;

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
        gcc_13_3 glibc_2_31 pkgs.stdenv pkgs;
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
