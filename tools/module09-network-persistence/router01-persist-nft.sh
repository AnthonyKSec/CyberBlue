#!/usr/bin/env bash
# CyberBlue Module 09: narrow routed client exception WIN11-01 -> DFIR-01:8000.
# Safe to rerun. Preserves all existing nftables rules, counters and default drop.
set -Eeuo pipefail

if (( EUID != 0 )); then echo 'ERROR: Run with sudo on ROUTER-01.' >&2; exit 1; fi
for cmd in nft ip python3 cp mktemp systemctl; do
  command -v "$cmd" >/dev/null || { echo "ERROR: Missing $cmd" >&2; exit 1; }
done
if ! ip -4 addr show dev ens18 | grep -Fq '10.10.20.1/24'; then
  echo 'STOP: SOC interface ens18 address differs; no changes.' >&2; exit 1
fi
if ! ip -4 addr show dev ens19 | grep -Fq '10.10.30.1/24'; then
  echo 'STOP: Victim interface ens19 address differs; no changes.' >&2; exit 1
fi
if [[ "$(sysctl -n net.ipv4.ip_forward)" != 1 ]]; then
  echo 'STOP: IPv4 forwarding disabled; no changes.' >&2; exit 1
fi
if [[ "$(systemctl is-enabled nftables.service)" != enabled ]]; then
  echo 'STOP: nftables service is not enabled; no changes.' >&2; exit 1
fi

src=/etc/nftables.conf
[[ -f "$src" ]] || { echo "STOP: $src missing" >&2; exit 1; }
rule='iifname "ens19" oifname "ens18" ip saddr 10.10.30.10 ip daddr 10.10.20.13 tcp dport 8000 ct state new counter accept'
backup="${src}.pre-module09.$(date -u +%Y%m%dT%H%M%SZ)"
candidate=$(mktemp /etc/.cyberblue-m09.XXXXXXXX.nft)
trap 'rm -f "${candidate:-}"' EXIT

python3 - "$src" "$candidate" "$rule" <<'PY'
from pathlib import Path
import re,sys
source,dest,rule = Path(sys.argv[1]),Path(sys.argv[2]),sys.argv[3]
data=source.read_text()
if 'table inet cyberblue {' not in data or 'type filter hook forward priority filter; policy drop;' not in data:
    raise SystemExit('STOP: expected default-deny cyberblue forward chain absent')
if 'tcp dport { 1514, 1515 }' not in data:
    raise SystemExit('STOP: expected pre-existing Wazuh rule absent')
# Only one bare terminal drop in this known short ruleset, not ct-state invalid drop.
drops=list(re.finditer(r'(?m)^(?P<indent>[ \t]*)counter[ \t]+drop[ \t]*$',data))
if len(drops)!=1:
    raise SystemExit(f'STOP: expected exactly one terminal counter drop; found {len(drops)}')
if data.count(rule)>1:
    raise SystemExit('STOP: repeated persistence rule in file')
if rule not in data:
    d=drops[0]
    data=data[:d.start()]+d.group('indent')+'# Module 09: WIN11-01 -> DFIR-01 Velociraptor TCP 8000\n'+d.group('indent')+rule+'\n'+data[d.start():]
    print('PREPARED: add one rule before final drop')
else:
    print('PASS: Rule already exists in persistent configuration')
dest.write_text(data)
PY

# Validate candidate while leaving the ACTIVE firewall rules entirely untouched.
nft -c -f "$candidate" || { echo 'FAIL: Candidate nftables syntax invalid; no changes.' >&2; exit 1; }
if ! cmp -s "$src" "$candidate"; then
  cp -a "$src" "$backup"
  # Atomic update on the same filesystem; retain the original owner and permissions.
  chmod --reference="$src" "$candidate"
  chown --reference="$src" "$candidate"
  mv -f "$candidate" "$src"
  if ! nft -c -f "$src"; then
    cp -a "$backup" "$src"
    echo 'FAIL: Persisted nftables failed check; original restored.' >&2
    exit 1
  fi
  printf 'BACKUP: %s\n' "$backup"
else
  echo 'UNCHANGED: Firewall rule already persisted.'
fi

# No firewall reload: preserve sessions and the existing default-deny chain.
if ! nft -a list chain inet cyberblue forward | grep -Fq 'ip saddr 10.10.30.10 ip daddr 10.10.20.13 tcp dport 8000 ct state new counter'; then
  nft insert rule inet cyberblue forward \
    iifname 'ens19' oifname 'ens18' \
    ip saddr 10.10.30.10 ip daddr 10.10.20.13 \
    tcp dport 8000 ct state new counter accept
  echo 'ADDED: narrow runtime firewall exception'
else
  echo 'PASS: runtime exception already present'
fi
nft -a list chain inet cyberblue forward | grep -E 'policy drop|10\.10\.30\.10 ip daddr 10\.10\.20\.13 tcp dport 8000'
printf 'PASS: ROUTER-01 persistent exception validated and active, no reload performed.\n'
printf 'NOTE: Reboot persistence still requires a reboot-and-retest checkpoint.\n'
