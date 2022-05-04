{
  description = "Zentria Nix Docker builder";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    docker-tools.url = "github:ZentriaMC/docker-tools";

    docker-tools.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils, docker-tools }:
    let
      supportedSystems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
    in
    flake-utils.lib.eachSystem supportedSystems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      rec {
        defaultPackage = packages.nixb;

        packages.dockerImage = import ./base.nix {
          inherit pkgs;
          inherit (docker-tools.lib) dockerConfig setupFHSScript symlinkCACerts;

          shadowLib = docker-tools.lib.shadow;
        };

        packages.nixb = pkgs.callPackage
          ({ stdenvNoCC, lib, makeWrapper, coreutils, jq }: stdenvNoCC.mkDerivation rec {
            pname = "nixb";
            version = self.rev or "dirty";

            src = ./.;

            buildInputs = [
              coreutils
              jq
            ];

            nativeBuildInputs = [
              makeWrapper
            ];

            dontConfigure = true;

            buildPhase = ''
              substituteInPlace nixb \
                --replace '"$(git rev-parse --show-toplevel)/with_nixb"' ${placeholder "out"}/bin/with_nixb

              substituteInPlace with_nixb \
                --replace '$(git rev-parse --show-toplevel)/lib' ${placeholder "out"}/lib
            '';

            installPhase = ''
              runHook preInstall

              install -D -m 755 with_nixb $out/bin/with_nixb
              install -D -m 755 nixb $out/bin/nixb
              cp -r lib $out/lib

              wrapProgram $out/bin/with_nixb --prefix PATH : ${lib.makeBinPath [ coreutils jq ]}
              wrapProgram $out/bin/nixb      --prefix PATH : ${lib.makeBinPath [ coreutils jq ]}

              runHook postInstall
            '';
          })
          { };
      });
}
