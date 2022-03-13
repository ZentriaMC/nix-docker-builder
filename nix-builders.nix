# ~/config/nix-builders.nix
let
  sshKey = "/etc/ssh/keys/nix_builder_ed25519";
in
[
  {
    hostName = "ssh-ng://dockerbuilder";
    inherit sshKey;
    systems = [ "aarch64-linux" ];
    supportedFeatures = [
      "benchmark"
    ];
  }
]
