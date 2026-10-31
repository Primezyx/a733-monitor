#!/usr/bin/env bash
# 把 src/ 与 packaging/ 打成可安装的 .deb
set -euo pipefail
VERSION="${1:-1.2.1}"
NAME="a733-monitor"
ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD="$(mktemp -d)"
TREE="$BUILD/$NAME"

mkdir -p "$TREE"/{DEBIAN,usr/bin,usr/lib/$NAME,lib/systemd/system} \
         "$TREE"/usr/share/{applications,icons/hicolor/scalable/apps}
install -m 0755 "$ROOT/src/a733-monitor"          "$TREE/usr/bin/$NAME"
install -m 0755 "$ROOT/src/gpu-sampler.py"        "$TREE/usr/lib/$NAME/gpu-sampler.py"
install -m 0644 "$ROOT/packaging/a733-monitor.service"   "$TREE/lib/systemd/system/"
install -m 0644 "$ROOT/packaging/a733-monitor.desktop"   "$TREE/usr/share/applications/"
install -m 0644 "$ROOT/packaging/a733-monitor.svg"       "$TREE/usr/share/icons/hicolor/scalable/apps/"

cat > "$TREE/DEBIAN/control" <<EOF
Package: $NAME
Version: $VERSION
Architecture: all
Maintainer: radxa <radxa@localhost>
Depends: python3, python3-tk
Section: utils
Priority: optional
Description: A733 system monitor (GPU/CPU/memory/network/disk)
 Real-time dashboard for Allwinner A733 boards: PowerVR GPU utilisation
 (via /sys/kernel/debug/pvr), per-core CPU load and frequency, memory,
 network and per-device disk read/write throughput.
EOF

printf '%s\n' '#!/bin/sh' 'set -e' \
  'systemctl daemon-reload || true' \
  "systemctl enable --now $NAME.service || true" \
  'update-desktop-database -q /usr/share/applications 2>/dev/null || true' \
  'exit 0' > "$TREE/DEBIAN/postinst"
printf '%s\n' '#!/bin/sh' 'set -e' \
  "systemctl disable --now $NAME.service 2>/dev/null || true" 'exit 0' > "$TREE/DEBIAN/prerm"
printf '%s\n' '#!/bin/sh' 'set -e' 'rm -rf /run/a733-monitor' \
  'systemctl daemon-reload 2>/dev/null || true' 'exit 0' > "$TREE/DEBIAN/postrm"
chmod 0755 "$TREE"/DEBIAN/{postinst,prerm,postrm}

dpkg-deb --build --root-owner-group "$TREE" "$ROOT/${NAME}_${VERSION}_all.deb"
rm -rf "$BUILD"
echo "built: $ROOT/${NAME}_${VERSION}_all.deb"
