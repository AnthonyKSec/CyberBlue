#!/usr/bin/env bash
# CyberBlue Module 09: one-host return route DFIR-01 -> WIN11-01.
# Safe to rerun. Changes no existing Netplan interface definitions.
set -Eeuo pipefail

if (( EUID != 0 )); then echo 'ERROR: Run with sudo on DFIR-01.' >&2; exit 1; fi
for command in netplan ip grep install mktemp; do
  command -v "$command" >/dev/null || { echo "ERROR: Missing $command" >&2; exit 1; }
done

if ! ip -4 addr show dev ens19 | grep -Fq '10.10.20.13/24'; then
  echo 'STOP: ens19 is not 10.10.20.13/24; no changes.' >&2; exit 1
fi
if ! ip -4 route get 10.10.20.1 | grep -Eq 'dev ens19 '; then
  echo 'STOP: SOC router does not route through ens19; no changes.' >&2; exit 1
fi
if ! ip -4 addr show dev ens18 | grep -Fq '192.168.12.147/24'; then
  echo 'STOP: unexpected management interface; no changes.' >&2; exit 1
fi

config=/etc/netplan/90-cyberblue-m09-win11-route.yaml
expected=$(cat <<'YAML'
# CyberBlue Module 09: specific return route for WIN11-01; preserve ens18 default route.
network:
  version: 2
  ethernets:
    ens19:
      routes:
        - to: 10.10.30.10/32
          via: 10.10.20.1
YAML
)

# Avoid adding a duplicate route if another, earlier Netplan configuration defines it.
if [[ ! -e "$config" ]] && netplan get ethernets.ens19.routes 2>/dev/null | grep -Fq '10.10.30.10/32'; then
  echo 'STOP: Netplan already defines this route elsewhere; inspect before continuing.' >&2
  exit 1
fi

created=0
if [[ -e "$config" ]]; then
  if [[ "$(cat "$config")" != "$expected" ]]; then
    echo "STOP: $config already exists with different content; no changes." >&2
    exit 1
  fi
  echo 'PASS: Persistent Netplan drop-in already matches desired route.'
else
  umask 077
  tmp=$(mktemp /etc/netplan/.cyberblue-m09.XXXXXXXX.yaml)
  trap 'rm -f "${tmp:-}"' EXIT
  printf '%s\n' "$expected" > "$tmp"
  install -m 600 -o root -g root "$tmp" "$config"
  created=1
  echo "CREATED: $config"
fi

# Generate backend configuration only: do NOT bounce management/network interfaces.
if ! netplan generate; then
  if ((created)); then rm -f "$config"; netplan generate >/dev/null 2>&1 || :; fi
  echo 'FAIL: Netplan validation failed. Newly-created drop-in removed.' >&2
  exit 1
fi

if ! netplan get ethernets.ens19.routes | grep -Fq '10.10.30.10/32'; then
  if ((created)); then rm -f "$config"; netplan generate >/dev/null 2>&1 || :; fi
  echo 'FAIL: Merged Netplan does not contain expected route.' >&2
  exit 1
fi

# Keep today's session working; boot will apply the persisted Netplan configuration.
ip -4 route replace 10.10.30.10/32 via 10.10.20.1 dev ens19
actual=$(ip -4 route get 10.10.30.10)
printf 'ROUTE: %s\n' "$actual"
if [[ "$actual" != *'via 10.10.20.1 dev ens19'* ]]; then
  echo 'FAIL: Expected runtime return route not installed.' >&2; exit 1
fi
printf 'PASS: DFIR-01 persistent /32 route staged and runtime route active.\n'
printf 'NOTE: Reboot persistence still requires a reboot-and-retest checkpoint.\n'
