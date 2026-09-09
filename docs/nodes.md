# The two live nodes

`config/evo.yaml` and `config/spark.yaml` are captured from the machines. A node
reads this file only at start, so nothing reconciles it and a rebuilt machine
loses every line — which is why they are here.

## What is load-bearing, and why

**`node-ip` and `flannel-iface` (evo).** evo carries `10.0.0.21` as a /32 on the
cable, not on the LAN. flannel does not follow `node-ip`: given no interface it
binds the one holding the default route, which here is wifi. Without both lines
the data plane crosses wifi in one direction while the apiserver session runs on
the cable — a half-migrated state worse than either end alone.

**`eviction-hard`.** k3s's stock value REPLACES the kubelet's default threshold
set rather than extending it, so a node configured with k3s's default has no
`memory.available` signal at all and the eviction manager can never fire on
memory pressure. With swap and `failSwapOn=false` the box swaps until it stops
responding.

**`image-gc-high-threshold` (evo).** A percentage of the whole 964G filesystem,
so the default 85% sits at 819G — a line a node with 131 distinct images in use
crosses and cannot get back under. The kubelet then runs GC every few minutes,
fails, and evicts *live* images instead: measured as the cloud re-pulling 2GB
from ghcr on every restart and taking fifteen minutes to come back. 92/85 gives
it a band it can reach. The eviction floor is untouched and is what actually
protects the node — 20Gi of imagefs, absolute, not a percentage.

## Applying a change

```sh
sudo systemctl restart grid
```

Containers survive it. The kubelet re-adopts what containerd is already running:
231 pods before, 230 after, API never down.
