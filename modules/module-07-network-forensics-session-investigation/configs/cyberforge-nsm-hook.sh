#!/bin/bash
set -u

VMID="$1"
PHASE="$2"

[ "$VMID" = "105" ] || exit 0

case "$PHASE" in
    post-start)
        logger -t cyberforge-nsm-hook \
          "NSM-01 started; rebuilding vmbr20 mirror"
        systemctl --no-block restart cyberforge-vmbr20-mirror.service
        ;;

    post-stop)
        logger -t cyberforge-nsm-hook \
          "NSM-01 stopped; removing vmbr20 mirror"
        systemctl --no-block stop cyberforge-vmbr20-mirror.service || true
        ;;
esac

exit 0
