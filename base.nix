# Based on https://github.com/NixOS/nix/blob/84507daaaa476e9ee4fbf87d1728a07ad6520ca0/docker.nix

{ pkgs
, dockerConfig
, shadowLib
, setupFHSScript
, symlinkCACerts
, name ? "nix-builder"
, tag ? "latest"
, channelName ? "nixpkgs"
, channelURL ? "https://nixos.org/channels/nixpkgs-unstable"
}:
let
  inherit (pkgs) lib;

  defaultPkgs = with pkgs; [
    bashInteractive
    coreutils
    curl
    dumb-init
    findutils
    git
    gnupg
    gnutar
    gzip
    nix
    openssh
  ];

  users = {
    root = {
      uid = 0;
      shell = "/bin/bash";
      home = "/root";
    };

    sshd = {
      uid = 1;
    };

    builder = {
      uid = 2;
      shell = "/bin/bash";
      password = "$6$Ts66.G77fW9A/4tG$Qk5hsn.WG9Cy8hNCddfrh9bK9SSu5QNnY04iEj3.VnwieicXdajubwBvCWN3ij0dChsJmGuZmkT6vFMyWeMuy0"; # "xyz"
    };

  } // lib.listToAttrs (
    map
      (
        n: {
          name = "nixbld${toString n}";
          value = {
            uid = 30000 + n;
            gid = 30000;
            groups = [ "nixbld" ];
            description = "Nix build user ${toString n}";
          };
        }
      )
      (lib.lists.range 1 32)
  );

  groups = {
    root.gid = 0;
    sshd.gid = 1;
    builder.gid = 2;
    nixbld.gid = 30000;
  };

  nixConf = {
    sandbox = "false";
    build-users-group = "nixbld";
    trusted-users = [ "builder" "root" ];
    experimental-features = [ "nix-command" "flakes" ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };

  sshdConfig = ''
    Port 22
    Include /etc/ssh/sshd_config.d/*
    Include /config/sshd/config.d/*
    AuthorizedKeysFile /nix/authorized_keys.d/%u /config/sshd/authorized_keys.d/%u
    PasswordAuthentication no
    ChallengeResponseAuthentication no
  '';

  baseSystem =
    let
      nixpkgs = pkgs.path;

      channel = pkgs.runCommand "channel-nixos" { } ''
        mkdir $out
        ln -s ${nixpkgs} $out/nixpkgs
        echo "[]" > $out/manifest.nix
      '';

      entrypointScript = pkgs.writeScript "docker-entrypoint.sh" ''
        #!${pkgs.bash}/bin/bash
        set -euo pipefail

        keyPath=/config/sshd/keys
        [ -f $keyPath/ssh_host_ed25519_key ] || ${pkgs.openssh}/bin/ssh-keygen -N "" -C "" -t ed25519 -f $keyPath/ssh_host_ed25519_key
        [ -f $keyPath/ssh_host_rsa_key ] || ${pkgs.openssh}/bin/ssh-keygen -N "" -C "" -t rsa -f $keyPath/ssh_host_rsa_key

        # Set up builder SSH keys
        mkdir -p /nix/authorized_keys.d
        echo -n "" > /nix/authorized_keys.d/builder
        if [ -n "''${SSH_KEYS:-}" ]; then
          (IFS=";"; keys=($SSH_KEYS); printf '%s\n' "''${keys[@]}") > "/nix/authorized_keys.d/builder"
        fi

        echo "############ SSH publicHostKey START"
        echo "$(base64 -w0 < $keyPath/ssh_host_ed25519_key.pub)"
        echo "############ SSH publicHostKey END"

        mkdir -p /nix/rootxdg/cache
        mkdir -p /nix/rootxdg/config

        # Start nix-daemon
        ${pkgs.coreutils}/bin/env \
          XDG_RUNTIME_DIR=/tmp \
          XDG_CACHE_HOME=/nix/rootxdg/cache \
          XDG_CONFIG_HOME=/nix/rootxdg/config \
          ${pkgs.nix}/bin/nix-daemon &
        disown

        ${pkgs.coreutils}/bin/env -i \
          ${pkgs.openssh}/bin/sshd \
          -f /etc/ssh/sshd_config \
          -h $keyPath/ssh_host_ed25519_key \
          -h $keyPath/ssh_host_rsa_key \
          -D \
          -e
      '';

      setupFHSScript' = setupFHSScript {
        inherit pkgs;
        targetDir = "$out/usr";
        paths.bin = defaultPkgs;
      };

      symlinkCACerts' = symlinkCACerts {
        inherit (pkgs) cacert;
        targetDir = "$out";
      };

      setupUsersScript' = shadowLib.setupUsersScript { };

      shadowFiles = shadowLib.setupUsers {
        inherit users groups;
      };
    in
    pkgs.runCommand "base-system"
      {
        inherit (shadowFiles) passwd shadow group gshadow;

        nixConfContents = (lib.concatStringsSep "\n" (lib.mapAttrsFlatten (n: v: "${n} = ${toString v}") nixConf)) + "\n";
        inherit sshdConfig;

        passAsFile = shadowFiles.passAsFile ++ [
          "nixConfContents"
          "sshdConfig"
        ];
        allowSubstitutes = false;
        preferLocalBuild = true;
      } ''
      # Create container fs layout
      for d in config etc/nix etc/ssh/authorized_keys.d root tmp usr var/empty; do
        mkdir -p $out/$d
      done

      # Set up config directory
      mkdir -p $out/config/sshd/authorized_keys.d
      mkdir -p $out/config/sshd/config.d
      mkdir -p $out/config/sshd/keys

      # Set up Nix directory
      mkdir -p $out/nix/authorized_keys.d
      mkdir -p $out/nix/rootxdg/cache

      # Setup FHS
      ${setupFHSScript'}
      ln -s usr/bin $out/bin
      ln -s bin $out/usr/sbin
      ln -s usr/bin $out/sbin
      ln -s usr/lib $out/lib
      ln -s usr/lib $out/lib64
      ln -s ../tmp $out/var/tmp

      ${symlinkCACerts'}
      ${setupUsersScript'}
      ln -s ${pkgs.iana-etc}/etc/protocols $out/etc/protocols
      ln -s ${pkgs.iana-etc}/etc/services $out/etc/services
      cat $nixConfContentsPath > $out/etc/nix/nix.conf
      cat $sshdConfigPath > $out/etc/ssh/sshd_config

      mkdir -p $out/nix/var/nix/gcroots
      mkdir -p $out/nix/var/nix/profiles/per-user/root

      ln -s ${entrypointScript} $out/docker-entrypoint.sh
    '';
in
pkgs.dockerTools.buildLayeredImageWithNixDb {
  inherit name tag;

  contents = [ baseSystem ];

  extraCommands = ''
    rm -rf nix-support
    ln -s /nix/var/nix/profiles nix/var/nix/gcroots/profiles

    chmod 1777 tmp
    chmod 700 config/sshd/keys
  '';

  config = {
    Entrypoint = [ "/usr/bin/dumb-init" "--" ];
    Cmd = [ "/docker-entrypoint.sh" ];
    Env = dockerConfig.env {
      PATH = lib.concatStringsSep ":" [
        "/usr/bin"
      ];
      TMPDIR = "/tmp";
    };
    Volumes = dockerConfig.volumes [
      "/config"
      "/nix"
      "/tmp"
    ];
    User = "root";
  };
}
