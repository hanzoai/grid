# grid

What a machine runs to be part of the cluster.

`grid` is Hanzo's Kubernetes substrate: one static binary, one config file, one
systemd unit. A node joins by starting it and leaves by stopping it.

```
systemctl status grid      # Hanzo Grid (Kubernetes node)
/etc/hanzo/grid/config.yaml
/etc/hanzo/grid/registries.yaml
/etc/hanzo/grid/env         0600, the join token
```

## It is not a fork, and that is the point

The binary is upstream k3s, unmodified. Every path it defaults to under
`/etc/rancher` and `/var/lib/rancher` is already a flag with an environment
variable:

```
--config FILE, -c FILE     (default "/etc/rancher/k3s/config.yaml")     [$K3S_CONFIG_FILE]
--data-dir value, -d       (default "/var/lib/rancher/k3s")             [$K3S_DATA_DIR]
--private-registry value   (default "/etc/rancher/k3s/registries.yaml")
```

So the estate's own names cost two lines in `unit/grid-*.service`. Forking to
change compiled-in defaults would buy the same result and a rebase against
upstream forever — for a string. When the binary itself should say `grid`, that
is a rename of one argv, not a maintained fork.

Fork when the behaviour must change. [visor](https://github.com/hanzoai/visor)
is a real fork of gVisor because the VFS is ours. This is not that.

## Install

```sh
sudo ./install.sh server    # the first node
sudo ./install.sh node      # every other node, with GRID_URL and GRID_TOKEN set
```

It writes `/etc/hanzo/grid/`, installs the unit, and starts it. An existing k3s
install is adopted in place: same binary, same data directory, so containers
keep running across the switch — measured at 231 pods before and 230 after.

## Layout

| path | what |
|---|---|
| `/etc/hanzo/grid/config.yaml` | kubelet args, node IP, eviction and image-GC thresholds |
| `/etc/hanzo/grid/registries.yaml` | mirrors and registry identity |
| `/etc/hanzo/grid/env` | `GRID_URL`, `GRID_TOKEN`. 0600, never committed |
| `/var/lib/rancher/k3s` | state. **Not yet moved** — see below |

The data directory is deliberately still upstream's. Every running container's
bind mounts point into it, so renaming it while they run breaks all of them.
That move belongs with a drained node, and both unit files say so in place.

## Distroless

Yes, and it is nearly free — because k3s is already self-contained:

```
$ file /usr/local/bin/k3s
ELF 64-bit LSB executable, x86-64, statically linked

$ ls /var/lib/rancher/k3s/data/current/bin | wc -l
324
```

Statically linked, and it unpacks its own 324-binary userspace — busybox,
containerd, runc, the CNI plugins, iptables — out of itself at start. A grid
image is `FROM scratch` plus one binary. There is no distro under it to strip.

What distroless does *not* buy: a node still needs the host kernel to have
cgroup v2, overlayfs and the netfilter modules, and `br_netfilter` and `overlay`
still have to be loaded before start. That is a kernel question, not an image
one, and it is where [hanzoai/os](https://github.com/hanzoai/os) comes in — the
full OS for when a machine needs more than a binary.

So the three sit like this:

| | |
|---|---|
| **grid** | the substrate a machine joins the cluster with |
| **visor** | the sandbox untrusted code runs in |
| **os** | the operating system underneath both |

## Docs

- [paths](docs/paths.md) — the path map, and why each one moved
- [distroless](docs/distroless.md) — the measurements behind the answer above
- [nodes](docs/nodes.md) — the two live configs, line by line
