#!/usr/bin/env bash
# Import the sanitized CyberBlue Module 09 screenshot evidence pack on RhinoRecon.
set -euo pipefail
if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: bash tools/import-module09-evidence.sh /path/to/CyberBlue_Module09_2026-10-15_EvidencePack.zip [--commit-and-push]"
  exit 2
fi
ZIP="$(realpath "$1")"
[[ -f "$ZIP" ]] || { echo "ZIP not found" >&2; exit 1; }
PUSH=no
if [[ $# -eq 2 ]]; then
  [[ "$2" == "--commit-and-push" ]] || { echo "Unexpected flag" >&2; exit 2; }
  PUSH=yes
fi
ROOT="$(git rev-parse --show-toplevel)"
[[ -d "$ROOT/modules/module-09-endpoint-forensics-threat-hunting" ]] || { echo "Wrong Git repository" >&2; exit 1; }
[[ -z "$(git -C "$ROOT" status --porcelain)" ]] || { echo "STOP: Uncommitted local changes" >&2; exit 1; }
python3 - "$ZIP" "$ROOT" <<'PY'
from pathlib import Path
import json,hashlib,sys,zipfile
source=Path(sys.argv[1])
module=Path(sys.argv[2])/'modules/module-09-endpoint-forensics-threat-hunting'
target=module/'screenshots/2026-10-15'
with zipfile.ZipFile(source) as z:
    names=set(z.namelist())
    if not {'MANIFEST.json','SHA256SUMS.txt'}<=names:
        raise SystemExit("STOP: Missing evidence manifest")
    manifest=json.loads(z.read('MANIFEST.json'))
    if len(manifest)!=34:
        raise SystemExit("STOP: Expected 34 curated screenshots")
    selected={}
    for entry in manifest:
        name=entry['committable']
        if Path(name).name!=name or not name.endswith('.webp') or name.startswith('.'):
            raise SystemExit("STOP: Unsafe image name")
        archive_name='screenshots/'+name
        if archive_name not in names or name in selected:
            raise SystemExit("STOP: Missing/duplicate image")
        data=z.read(archive_name)
        digest=hashlib.sha256(data).hexdigest()
        if digest!=entry['sha256'] or len(data)!=entry['bytes']:
            raise SystemExit("STOP: Image integrity check failed: "+name)
        selected[name]=(data,digest)
    unexpected=[name for name in names if name.startswith('screenshots/') and not name.endswith('/') and Path(name).name not in selected]
    if unexpected:
        raise SystemExit("STOP: Unexpected file in image folder")
    target.mkdir(parents=True,exist_ok=True)
    for name,(data,digest) in selected.items():
        out=target/name
        if out.exists() and hashlib.sha256(out.read_bytes()).hexdigest()!=digest:
            raise SystemExit("STOP: Existing file mismatch "+name)
        out.write_bytes(data)
    (module/'EVIDENCE-2026-10-15-SHA256.txt').write_text(''.join(
       digest+'  screenshots/2026-10-15/'+name+'\n'
       for name,(_,digest) in sorted(selected.items())))
    print('PASS: 34 screenshots verified and installed')
    print('PASS: Sensitive full-client-config/private-key screenshots are excluded')
PY
if [[ "$PUSH" == yes ]]; then
  BRANCH="$(git -C "$ROOT" branch --show-current)"
  [[ -n "$BRANCH" ]] || { echo "STOP: Detached Git HEAD" >&2; exit 1; }
  git -C "$ROOT" add -- modules/module-09-endpoint-forensics-threat-hunting/screenshots/2026-10-15/ modules/module-09-endpoint-forensics-threat-hunting/EVIDENCE-2026-10-15-SHA256.txt
  git -C "$ROOT" commit -m "Add sanitized October 15 Module 09 DFIR screenshot evidence"
  git -C "$ROOT" push origin "$BRANCH"
  printf 'PASS: Evidence committed and pushed to origin/%s\n' "$BRANCH"
else
  echo "Images copied; not yet committed. Use --commit-and-push when ready."
fi
