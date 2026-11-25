#!/bin/bash
# ReadyStack Kubernetes entrypoint. One container, two ways to run it:
#
#   control plane (the image default, user kube, no extra privileges): etcd, kube-apiserver,
#     kube-controller-manager and kube-scheduler. A real Kubernetes API with no nodes: Pods stay Pending.
#   single-node cluster (started with --privileged --user 0): the same control plane, still run as kube,
#     plus the node: containerd, kubelet and kube-proxy (root), CoreDNS (kube) and a ptp CNI network, so
#     Pods run in this container. A Kubernetes node needs root on Linux (mounts, cgroups, iptables).
#
# The cluster PKI and kubeconfigs are made with kubeadm's own phases (`kubeadm init phase certs` /
# `kubeconfig`) under /var/lib/kubernetes; the components then run under supervisord with the flags kubeadm
# writes into its static-pod manifests. Nothing is downloaded at start.
set -euo pipefail
die() { echo "kubernetes: $*" >&2; exit 1; }
log() { echo "kubernetes: $*"; }

K=/var/lib/kubernetes
PKI="$K/pki"
R=/run/kubernetes
V="${KUBE_VERSION:?KUBE_VERSION is set in the image}"
UID_NOW=$(id -u)

MODE="${KUBE_MODE:-auto}"
case "$MODE" in
  auto) if [ "$UID_NOW" = 0 ]; then MODE=node; else MODE=control-plane; fi ;;
  node|control-plane) ;;
  *) die "KUBE_MODE must be auto, node or control-plane (got '$MODE')" ;;
esac
if [ "$MODE" = node ] && [ "$UID_NOW" != 0 ]; then
  die "the node (kubelet, containerd) needs root: start the container with --privileged --user 0, or set KUBE_MODE=control-plane"
fi

# This start's runtime files (supervisord.conf, the kubeadm config, component configs) are rebuilt every start.
mkdir -p "$R" && find "$R" -mindepth 1 -delete

# as_kube CMD...: the control plane always runs as kube; in node mode this entrypoint is root and drops to kube.
as_kube() { if [ "$UID_NOW" = 0 ]; then setpriv --reuid=kube --regid=kube --init-groups -- "$@"; else "$@"; fi; }

ADVERTISE="${KUBE_ADVERTISE_ADDRESS:-$(hostname -i | awk '{print $1}')}"
[ -n "$ADVERTISE" ] || die "could not read this container's IP address; set KUBE_ADVERTISE_ADDRESS"
NODE_NAME="${KUBE_NODE_NAME:-$(hostname | tr '[:upper:]' '[:lower:]')}"
PUBLIC="${KUBE_PUBLIC_ENDPOINT:-localhost:6443}"
SVC_CIDR="${SERVICE_CLUSTER_IP_RANGE:-10.96.0.0/12}"
POD_CIDR="${CLUSTER_CIDR:-10.244.0.0/16}"

# The service network's first address (the kubernetes Service) and its tenth (kube-dns), as kubeadm picks them.
ip2int() { local IFS=.; read -r a b c d <<<"$1"; echo $(( (a << 24) + (b << 16) + (c << 8) + d )); }
int2ip() { echo "$(( ($1 >> 24) & 255 )).$(( ($1 >> 16) & 255 )).$(( ($1 >> 8) & 255 )).$(( $1 & 255 ))"; }
case "$SVC_CIDR" in */*) ;; *) die "SERVICE_CLUSTER_IP_RANGE must be an IPv4 CIDR such as 10.96.0.0/12" ;; esac
SVC_BITS=${SVC_CIDR#*/}; SVC_BASE=$(( $(ip2int "${SVC_CIDR%/*}") & ~((1 << (32 - SVC_BITS)) - 1) & 0xFFFFFFFF ))
DNS_IP=$(int2ip $(( SVC_BASE + 10 )))

# ---------------------------------------------------------------------------------------------------------------------
# 1) Node prerequisites (root only). Everything here stays inside this container: its own cgroup, mount and network
#    namespaces. Nothing writes the host's kernel settings (see the sysctl note below).
# ---------------------------------------------------------------------------------------------------------------------
if [ "$MODE" = node ]; then
  mount --make-rshared / 2>/dev/null || die "cannot change mount propagation: the node needs --privileged"
  [ -f /sys/fs/cgroup/cgroup.controllers ] || die "the node needs cgroup v2 (unified hierarchy) on the host"
  [ -w /sys/fs/cgroup/cgroup.subtree_control ] || die "/sys/fs/cgroup is read-only: the node needs --privileged"
  # cgroup v2 allows controllers in a child group only when the parent has no processes of its own, so every
  # process is moved to /init first; pods then live under /kubelet (kubelet cgroupRoot).
  mkdir -p /sys/fs/cgroup/init /sys/fs/cgroup/kubelet
  for _ in 1 2 3; do
    for p in $(cat /sys/fs/cgroup/cgroup.procs); do echo "$p" > /sys/fs/cgroup/init/cgroup.procs 2>/dev/null || true; done
    for c in $(cat /sys/fs/cgroup/cgroup.controllers); do echo "+$c" > /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null || true; done
    grep -qw memory /sys/fs/cgroup/cgroup.subtree_control && break
  done
  for c in cpu memory pids; do grep -qw "$c" /sys/fs/cgroup/cgroup.subtree_control || die "cgroup controller $c is not available to this container"; done
  # containerd's overlayfs snapshotter cannot sit on the container's own overlay root: with a volume at
  # /var/lib/containerd (the documented run command) it is used; without one, containerd falls back to its native
  # snapshotter (full copies of each layer: slower and more disk, but it works).
  SNAPSHOTTER=overlayfs
  if [ "$(stat -f -c %T /var/lib/containerd)" = overlayfs ]; then
    SNAPSHOTTER=native
    log "/var/lib/containerd is not a volume: using containerd's native snapshotter (mount a volume there, -v kube-containerd:/var/lib/containerd, for overlayfs)"
  fi
  sed -e "s#@SNAPSHOTTER@#$SNAPSHOTTER#" /etc/containerd/config.toml > "$R/containerd.toml"
  # Runtime state starts empty on every start, as on a host after a reboot.
  for d in /run/containerd /run/netns /run/cni-ipam-state; do
    mkdir -p "$d"; mountpoint -q "$d" || mount -t tmpfs -o mode=0755 tmpfs "$d"
  done
  # kubelet checks six kernel settings at start (vm.overcommit_memory, vm.panic_on_oom, kernel.panic,
  # kernel.panic_on_oops, kernel.keys.root_maxkeys/maxbytes) and, by default, WRITES its values to them. In a
  # privileged container those are the HOST's settings (kernel.panic=10 + panic_on_oops=1 would make the host reboot on
  # any kernel oops). This image runs kubelet with protectKernelDefaults=true, so it never writes them, and shows
  # kubelet its expected values with read-only files bind-mounted over these six entries in this container's mount
  # namespace only. The host keeps its own values.
  mkdir -p "$R/sysctl"
  for kv in vm/overcommit_memory=1 vm/panic_on_oom=0 kernel/panic=10 kernel/panic_on_oops=1 \
            kernel/keys/root_maxkeys=1000000 kernel/keys/root_maxbytes=25000000; do
    f="/proc/sys/${kv%=*}"; want="${kv#*=}"
    [ "$(cat "$f" 2>/dev/null)" = "$want" ] && continue
    v="$R/sysctl/$(echo "${kv%=*}" | tr / .)"
    echo "$want" > "$v"; chmod 0444 "$v"
    mountpoint -q "$f" || mount --bind -o ro "$v" "$f" || die "cannot mask $f"
  done
  # The volume may come from an older start as another user; the control plane reads it as kube.
  chown kube:kube "$K"
fi

# ---------------------------------------------------------------------------------------------------------------------
# 2) PKI and kubeconfigs, kubeadm's own phases, as kube.
# ---------------------------------------------------------------------------------------------------------------------
[ -w "$K" ] || [ "$UID_NOW" = 0 ] || die "$K is not writable by $(id -un) (uid $UID_NOW); use a Docker named volume, not a host directory"
as_kube mkdir -p "$PKI" "$K/etcd" "$K/manifests"
chmod 0700 "$K/etcd"
SANS="localhost,127.0.0.1,${PUBLIC%:*}${KUBE_API_SANS:+,$KUBE_API_SANS}"
san_yaml=$(echo "$SANS" | tr ',' '\n' | awk 'NF && !seen[$0]++ {printf "    - \"%s\"\n", $0}')
cat > "$R/kubeadm.yaml" <<EOF
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "$ADVERTISE"
  bindPort: 6443
nodeRegistration:
  name: "$NODE_NAME"
  criSocket: unix:///run/containerd/containerd.sock
  taints: []
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
kubernetesVersion: "$V"
clusterName: kubernetes
certificatesDir: $PKI
controlPlaneEndpoint: "$PUBLIC"
apiServer:
  certSANs:
$san_yaml
networking:
  serviceSubnet: "$SVC_CIDR"
  podSubnet: "$POD_CIDR"
  dnsDomain: cluster.local
etcd:
  local:
    dataDir: $K/etcd
EOF
chmod 0644 "$R/kubeadm.yaml"
umask 077

# The CA, service-account key and front-proxy CA are made once and kept: a new CA invalidates every credential.
# Leaf certificates are valid for one year; one that expires within 30 days is re-issued from the same CA at start.
# The API serving certificate names this container's address, which Docker changes when the container is recreated,
# so it is re-issued whenever that address is not in it.
for c in apiserver apiserver-kubelet-client apiserver-etcd-client front-proxy-client etcd/server etcd/peer etcd/healthcheck-client; do
  [ -s "$PKI/$c.crt" ] || continue
  if ! openssl x509 -in "$PKI/$c.crt" -noout -checkend 2592000 >/dev/null 2>&1; then
    log "re-issuing $c.crt (expires within 30 days)"; rm -f "$PKI/$c.crt" "$PKI/$c.key"
  fi
done
if [ -s "$PKI/apiserver.crt" ] && ! openssl x509 -in "$PKI/apiserver.crt" -noout -ext subjectAltName 2>/dev/null \
     | tr ',' '\n' | grep -qx "[[:space:]]*IP Address:$ADVERTISE"; then
  log "re-issuing apiserver.crt for address $ADVERTISE"; rm -f "$PKI/apiserver.crt" "$PKI/apiserver.key"
fi
as_kube kubeadm init phase certs all --config "$R/kubeadm.yaml" >/dev/null

# Kubeconfigs that name this start's address or node are rewritten every start; admin.conf and super-admin.conf are
# kept (they are handed to people) unless missing, expiring within 30 days, or pointing at another endpoint.
kc_ok() { [ -s "$1" ] && grep -q "server: https://$PUBLIC\$" "$1" \
          && grep -o 'client-certificate-data: .*' "$1" | cut -d' ' -f2 | base64 -d 2>/dev/null \
             | openssl x509 -noout -checkend 2592000 >/dev/null 2>&1; }
for f in admin super-admin; do kc_ok "$K/$f.conf" || rm -f "$K/$f.conf"; done
rm -f "$K/controller-manager.conf" "$K/scheduler.conf" "$K/kubelet.conf" "$K/kube-proxy.conf" "$K/coredns.conf"
phases="controller-manager scheduler"
[ -s "$K/admin.conf" ] || phases="$phases admin"
[ -s "$K/super-admin.conf" ] || phases="$phases super-admin"
[ "$MODE" = node ] && phases="$phases kubelet"
for p in $phases; do
  as_kube kubeadm init phase kubeconfig "$p" --config "$R/kubeadm.yaml" --kubeconfig-dir "$K" >/dev/null
done
if [ "$MODE" = node ]; then
  # kube-proxy and CoreDNS authenticate as system:kube-proxy (bound by Kubernetes' own system:node-proxier role) and
  # system:coredns (bound at start by kube-init) with client certificates from the cluster CA.
  as_kube sh -c "kubeadm kubeconfig user --config '$R/kubeadm.yaml' --client-name system:kube-proxy > '$K/kube-proxy.conf'"
  as_kube sh -c "kubeadm kubeconfig user --config '$R/kubeadm.yaml' --client-name system:coredns > '$K/coredns.conf'"
fi

# ---------------------------------------------------------------------------------------------------------------------
# 3) This start's settings for the components (kube-svc reads them) and the supervisord programs for this mode.
# ---------------------------------------------------------------------------------------------------------------------
umask 022
{
  printf 'MODE=%q\nADVERTISE=%q\nNODE_NAME=%q\nPUBLIC=%q\nSVC_CIDR=%q\nPOD_CIDR=%q\nDNS_IP=%q\n' \
    "$MODE" "$ADVERTISE" "$NODE_NAME" "$PUBLIC" "$SVC_CIDR" "$POD_CIDR" "$DNS_IP"
  printf 'EXTRA_APISERVER_ARGS=%q\nEXTRA_KUBELET_ARGS=%q\n' "${KUBE_APISERVER_EXTRA_ARGS:-}" "${KUBELET_EXTRA_ARGS:-}"
} > "$R/env"

prog() {  # prog NAME PRIORITY USER [extra supervisord lines...]
  local name=$1 prio=$2 user=$3; shift 3
  printf '\n[program:%s]\ncommand=/usr/local/bin/kube-svc %s\npriority=%s\n' "$name" "$name" "$prio"
  [ "$UID_NOW" = 0 ] && printf 'user=%s\n' "$user"
  printf 'environment=HOME="%s"\nautorestart=true\nstartsecs=5\nstartretries=100\nstopwaitsecs=30\n' \
    "$([ "$user" = kube ] && echo "$K" || echo /root)"
  printf 'stdout_logfile=/dev/stdout\nstdout_logfile_maxbytes=0\nredirect_stderr=true\n'
  for l in "$@"; do printf '%s\n' "$l"; done
}
{
  printf '; generated by kube-entrypoint.sh for this start (mode: %s)\n' "$MODE"
  printf '[supervisord]\nnodaemon=true\nlogfile=/dev/null\nlogfile_maxbytes=0\npidfile=%s/supervisord.pid\n' "$R"
  [ "$UID_NOW" = 0 ] && printf 'user=root\n'
  printf '\n[unix_http_server]\nfile=%s/supervisor.sock\nchmod=0700\n' "$R"
  printf '\n[rpcinterface:supervisor]\nsupervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface\n'
  printf '\n[supervisorctl]\nserverurl=unix://%s/supervisor.sock\n' "$R"
  prog etcd 10 kube
  prog kube-apiserver 20 kube
  prog kube-controller-manager 30 kube
  prog kube-scheduler 30 kube
  if [ "$MODE" = node ]; then
    prog containerd 40 root
    prog kubelet 50 root
    prog kube-proxy 50 root
    prog coredns 60 kube
  fi
  prog kube-init 90 kube
} > "$R/supervisord.conf"

log "starting the $MODE ($( [ "$MODE" = node ] && echo "node $NODE_NAME, " )API https://$ADVERTISE:6443, clients use https://$PUBLIC)"
exec env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin LANG=C.UTF-8 TZ="${TZ:-UTC}" \
  HOME="$( [ "$UID_NOW" = 0 ] && echo /root || echo "$K" )" KUBECONFIG="$K/admin.conf" \
  /usr/bin/supervisord -n -c "$R/supervisord.conf"
