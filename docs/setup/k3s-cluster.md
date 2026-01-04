# k3s Cluster Setup

Single k3s cluster with Cilium CNI spanning Mac Mini M4 (OrbStack VM) and Raspberry Pi 4.

## Architecture

```
Mac Mini M4 (macOS)
└── OrbStack Ubuntu VM "macmini"
    └── k3s server (control-plane + worker)
        └── Cilium CNI
    └── Port forwarding → LAN IP: 192.168.88.2

Raspberry Pi 4
└── k3s agent (worker)
    └── Cilium agent
└── LAN IP: 192.168.88.3
└── 8TB disk at /media/emby/
```

## Step 1: Create OrbStack VM

1. Open OrbStack, create Ubuntu 24.04 LTS machine named `macmini`
2. OrbStack Settings → Machines → Enable "Expose ports to LAN"

## Step 2: Install k3s Server

```bash
orb -m macmini

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="\
  --disable traefik \
  --disable-kube-proxy \
  --flannel-backend=none \
  --disable-network-policy \
  --node-external-ip 192.168.88.2 \
  --tls-san 192.168.88.2" sh -
```

## Step 3: Configure kubeconfig

```bash
orb -m macmini sudo cat /etc/rancher/k3s/k3s.yaml | \
  sed 's/127.0.0.1/localhost/' > ~/.kube/config
chmod 600 ~/.kube/config
```

## Step 4: Install Cilium

```bash
helm dependency update kubernetes/charts/cilium

helm upgrade --install cilium kubernetes/charts/cilium \
  --namespace kube-system \
  -f kubernetes/charts/cilium/values/homelab.yaml
```

## Step 5: Join Raspberry Pi

Get token:
```bash
orb -m macmini sudo cat /var/lib/rancher/k3s/server/node-token
```

Install agent:
```bash
ssh raspberrypi.local

curl -sfL https://get.k3s.io | \
  K3S_URL=https://192.168.88.2:6443 \
  K3S_TOKEN='<token>' sh -
```

## Step 6: Label and Taint Nodes

```bash
kubectl label node macmini node-role.kubernetes.io/worker=true
kubectl label node macmini node-type=primary
kubectl label node raspberrypi node-role.kubernetes.io/worker=true
kubectl label node raspberrypi node-type=media

kubectl taint node raspberrypi dedicated=media:NoSchedule
```

## Scheduling on Raspberry Pi

```yaml
nodeSelector:
  node-type: media
tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "media"
    effect: "NoSchedule"
```

## Important: Mac LAN IP

Both `--tls-san` (k3s) and `k8sServiceHost` (Cilium) must use Mac's LAN IP (192.168.88.2), not the VM's internal IP. This ensures all nodes can reach the API server.

## Cross-Node Networking

OrbStack VM has an internal IP (192.168.139.x) that Cilium uses for VXLAN tunneling. Raspberry Pi can't reach this IP directly, so MikroTik router NAT rules are required.

See [orbstack-networking.md](orbstack-networking.md) for details on the NAT configuration.
