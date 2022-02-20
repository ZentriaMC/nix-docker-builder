#!/usr/bin/env bash
set -euo pipefail

if [ -z "${IN_CONTAINER:-}" ]; then
	name="nix-builder"

	flags=()
	if [ -n "${PERSIST_STORE:-}" ]; then
		docker volume create "${name}-store" || true
		flags+=(-v "${name}-store:/nix")
	fi

	exec docker run --rm -ti --name "${name}" \
		-e IN_CONTAINER=1 \
		-v "$(git rev-parse --show-toplevel):/workdir" \
		"${flags[@]}" \
		nixos/nix:latest bash /workdir/hack/bootstrap_image.sh
fi

# Setup Nix config
mkdir -p "${HOME}"/.config/nix
echo "experimental-features = nix-command flakes" > "${HOME}"/.config/nix/nix.conf

cd /workdir

result="/tmp/result.${RANDOM}"

nix build -L --out-link "${result}" .#dockerImage

rm -rf result || true
cat "${result}" > /workdir/result
