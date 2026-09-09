# Distroless

Yes, and it costs almost nothing — because the binary is already self-contained.
Measured on a live node:

```
$ file /usr/local/bin/k3s
ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked

$ ls /var/lib/rancher/k3s/data/current/bin | wc -l
324
```

Statically linked, so there is no libc to carry. And it unpacks its own 324-binary
userspace out of itself at start — busybox, containerd, runc, the CNI plugins,
iptables, blkid, nsenter. A grid image is `FROM scratch` plus one file. There is
no distro underneath to strip, which is the usual work in going distroless.

## What it does not buy

An image says nothing about the kernel it runs on, and a Kubernetes node is a
kernel client before it is anything else:

- cgroup v2, mounted and writable
- overlayfs
- `br_netfilter` and `overlay` loaded — the unit does this in `ExecStartPre`,
  and a container cannot `modprobe` for the host
- `/sys/fs/cgroup`, `/proc`, `/dev` and the network namespace, host-shared

So a containerised node is `--privileged` with the host's cgroup and net
namespaces. That is fine for a dev cluster (this is how k3d works) and it is not
isolation. Isolation of *workloads* is [visor](https://github.com/hanzoai/visor)'s
job, one layer up, and it is a different problem.

## Where this actually matters

Not for the nodes we run: those install grid as a systemd service on the host, and
there is no image in the path at all. It matters for

- **the sandbox images agentic coding runs in**, where a small, hash-pinned image
  is the whole point, and
- **[hanzoai/os](https://github.com/hanzoai/os)**, when a machine needs a real OS
  under the binary rather than beside it.
