#!/bin/sh
# Install grid on this machine. Idempotent, and it ADOPTS an existing k3s rather
# than replacing it: same binary, same data directory, so containers keep running
# across the switch.
set -eu

role="${1:-node}"
case "$role" in server|node) ;; *) echo "usage: install.sh [server|node]" >&2; exit 2 ;; esac

[ "$(id -u)" = 0 ] || { echo "run as root" >&2; exit 1; }
command -v k3s >/dev/null || { echo "k3s binary not found — install it first, grid does not vendor one" >&2; exit 1; }

etc=/etc/hanzo/grid
mkdir -p "$etc"

# Adopt what the machine already has, so a switch never loses a hand-tuned line.
for f in config.yaml registries.yaml; do
  [ -f "$etc/$f" ] && continue
  [ -f "/etc/rancher/k3s/$f" ] && cp "/etc/rancher/k3s/$f" "$etc/$f" && echo "adopted $f"
done
[ -f "$etc/config.yaml" ] || : > "$etc/config.yaml"

# The join credential. GRID_URL/GRID_TOKEN in the environment win; otherwise an
# existing k3s env file is adopted. Never world-readable, never committed.
if [ ! -f "$etc/env" ]; then
  if [ -n "${GRID_TOKEN:-}" ]; then
    printf 'K3S_URL=%s\nK3S_TOKEN=%s\n' "${GRID_URL:-}" "$GRID_TOKEN" > "$etc/env"
  else
    for old in /etc/systemd/system/k3s-agent.service.env /etc/systemd/system/k3s.service.env; do
      [ -f "$old" ] && cp "$old" "$etc/env" && break
    done
  fi
fi
touch "$etc/env"; chmod 600 "$etc/env"

src="unit/grid-$( [ "$role" = server ] && echo server || echo node ).service"
[ -f "$src" ] || { echo "missing $src" >&2; exit 1; }
cp "$src" /etc/systemd/system/grid.service

systemctl disable --now k3s k3s-agent 2>/dev/null || true
systemctl daemon-reload
systemctl enable --now grid
echo "grid is $(systemctl is-active grid)"
