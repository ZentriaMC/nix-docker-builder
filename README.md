# Nix Docker builder

**Heavy WIP**

Needing to build Linux derivations on macOS, but no Linux machine nearby and `nixos/nix` image is inconvenient to set up\*?

Use with [lima][lima], or [colima][colima], or even [Docker.app][docker-app]

\* Right now distributed builds have quite subpar experience, so it is not advisable for beginner to use them.

## Setting up

### Building builder image on Linux

Easiest choice; `nix build .#dockerImage`, scp image to macOS and import.

### Building builder image on macOS with Docker/-compatible

Run `./hack/bootstrap_image.sh`, and import image from `result` file in repository directory

### Launching

You can use `./hack/run.sh`. It will set up the builder for your user (including needed modifications to `~/.ssh/config` etc.)

## Using with Nix

See https://nixos.org/manual/nix/stable/advanced-topics/distributed-builds.html

This repository provides a `nixb` wrapper to invoke `nix` with remote builders flag.

### Testing

```shell
./test/remote_build/test.sh
cat ./test/remote_build/result
```

[lima]: https://github.com/lima-vm/lima
[colima]: https://github.com/abiosoft/colima
[docker-app]: https://docs.docker.com/desktop/mac/install/
