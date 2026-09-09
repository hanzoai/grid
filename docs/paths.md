# Paths

| grid | upstream default | how |
|---|---|---|
| `/etc/hanzo/grid/config.yaml` | `/etc/rancher/k3s/config.yaml` | `--config`, `$K3S_CONFIG_FILE` |
| `/etc/hanzo/grid/registries.yaml` | `/etc/rancher/k3s/registries.yaml` | `--private-registry` |
| `/etc/hanzo/grid/env` | `/etc/systemd/system/k3s*.service.env` | `EnvironmentFile=` |
| `/var/lib/rancher/k3s` | same | `--data-dir`, `$K3S_DATA_DIR` — **not moved** |

Every one of these is a flag upstream already exposes. That is the whole argument
against forking: the defaults are the only thing a fork would change, and they are
not compiled-in behaviour, they are argv.

## Why the data directory has not moved

Every running container's bind mounts resolve into it. Renaming it while they run
leaves each one pointing at a path that no longer exists, and the node comes back
with its workloads broken rather than restarted. `mv` on the same filesystem is
instant, so the move is cheap — it just has to happen with the node drained.

It pairs naturally with putting containerd on its own filesystem, which is the
real reason to do it: on a 964G root shared with everything else, the kubelet's
image GC threshold is a percentage that a busy node crosses and cannot get back
under, so it evicts live images instead and every restart becomes a re-pull.

## Adopting an existing k3s

`install.sh` copies the machine's existing `config.yaml`, `registries.yaml` and
join credential into `/etc/hanzo/grid` before switching the unit, so no hand-tuned
line is lost. The binary and the data directory do not change, which is why
containers survive: measured at 231 pods before the switch and 230 after, with the
API never dropping a request.
