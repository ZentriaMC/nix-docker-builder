#!/usr/bin/env bash
set -euo pipefail

# Sets up ssh configuration and keys, and runs the image

key="${HOME}/.ssh/nix_builder_ed25519"
config="${HOME}/.ssh/config_nix_builder"
if ! [ -f "${key}" ]; then
	ssh-keygen -N "" -C "" -t ed25519 -f "${key}"
fi

cat > "${config}" <<EOF
Host dockerbuilder
	User builder
	IdentityFile ~/.ssh/nix_builder_ed25519
	StrictHostKeyChecking no
	Hostname 127.0.0.1
	Port 10122

# vim: ft=sshconfig
EOF

if ! grep -q -F "Include ~/.ssh/config_nix_builder" "${HOME}/.ssh/config"; then
	tmp="${HOME}/.ssh/.config.${RANDOM}"
	(echo "Include ~/.ssh/config_nix_builder # Added by ZentriaMC/nix-docker-builder"; echo "") > "${tmp}"
	cat "${HOME}/.ssh/config" >> "${tmp}"
	mv "${tmp}" "${HOME}/.ssh/config"
fi

name="nixos-builder"
daemonize=0
reset=0

while [ -n "${1:-}" ]; do
	arg="${1}"
	case "${arg}" in
		--daemonize)
			daemonize=1
			;;
		--reset)
			reset=1
			;;
		*)
			echo "Unknown flag '${arg}'"
			exit 2
			;;
	esac
	shift
done

docker_flags=()
if (( daemonize )); then
	docker_flags+=(--detach)
fi

if (( reset )); then
	docker volume rm "${name}-store" "${name}-config" || true
fi

docker volume create "${name}-store" || true
docker volume create "${name}-config" || true

exec docker run --rm -ti --name "${name}" \
	-e SSH_KEYS="$(< "${key}.pub")" \
	-v "${name}-store:/nix" \
	-v "${name}-config:/config" \
	--tmpfs /tmp:exec \
	--read-only \
	"${docker_flags[@]}" \
	-p 127.0.0.1:10122:22 \
	nix-builder:latest
