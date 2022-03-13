#!/usr/bin/env bash
set -euo pipefail

system="aarch64-linux"
nexpr="$(cat <<EOF
let
  nixpkgs = fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/b66b39216b1fef2d8c33cc7a5c72d8da80b79970.tar.gz";
    sha256 = "0xqxrmdr3adcdj1ksnwf8w7d0qjzsc4sgzfcmvvrpk7hrc5q9cvg";
  };

  pkgs = import nixpkgs {
    system = "${system}";
  };
in
pkgs.callPackage ./drv.nix { }

EOF
)"

top="$(git rev-parse --show-toplevel)"
export NIX_BUILDERS_CONFIG="${top}/nix-builders.nix"
nixb="${top}/nixb"

cd "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")"
"${nixb}" build --print-build-logs --impure \
	--system "${system}" \
	--expr "${nexpr}" --show-trace
