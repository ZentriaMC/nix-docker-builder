# ~/config/nix-builders.nix
let
  sshKey = "/etc/ssh/keys/nix_builder_ed25519";
in
{
  "ssh-ng://dockerbuilder" = {
    inherit sshKey;
    arches = [ "aarch64-linux" ];
    supportedFeatures = [
      "benchmark"
    ];
  };
}
