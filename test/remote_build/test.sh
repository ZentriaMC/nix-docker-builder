#!/usr/bin/env bash
set -euo pipefail

nexpr="$(cat << 'EOF'
let
  # TODO: does not work!
  # error: path '.../store/03g58m9vm235nj99xvawxlir4yimjdr8-source' is not in the Nix store
  #nixpkgs = builtins.fetchTarball {
  #  url = "https://github.com/NixOS/nixpkgs/archive/b66b39216b1fef2d8c33cc7a5c72d8da80b79970.tar.gz";
  #  sha256 = "0xqxrmdr3adcdj1ksnwf8w7d0qjzsc4sgzfcmvvrpk7hrc5q9cvg";
  #};

  pkgs = import <nixpkgs> { # nixpkgs {
    system = "aarch64-linux";
  };
in
pkgs.callPackage ./drv.nix { }
EOF
)"

export NIX_STORE="$(git rev-parse --show-toplevel)/store"
nixb="$(git rev-parse --show-toplevel)/nixb"

cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")"
"${nixb}" --print-build-logs --impure \
	--expr "${nexpr}" --show-trace
