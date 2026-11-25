# =====================================================================
# Kubernetes v1.37.2 L-009 HERMETIC OFFLINE BUILD — the canonical, attestation-producing build. build_kit runs
#   docker buildx build --builder readystack-builder-max --network=none
#     --attest type=provenance,mode=max --attest type=sbom --push <git-context>
# Pinned-public-base + vendored model: golang 1.26.10 + ubuntu 24.04 pinned BY DIGEST (BASE_IMAGE_DIGESTS.lock);
# vendored/*-src are fully vendored Go trees (GOPROXY=off, vendor/), every binary compiled here on the one pinned Go;
# vendored/debs is the apt closure, vendored/seccomp-debs Debian's libseccomp-dev for runc, both dpkg offline.
# Dockerfile and Dockerfile.offline are byte copies of this file (the repo-wide convention).
#
# SHAPE: one container, two ways to run it (kube-entrypoint.sh):
#   default (USER 999 kube, no extra privileges): the control plane — etcd, kube-apiserver, kube-controller-manager,
#     kube-scheduler. A Kubernetes API with no node.
#   --privileged --user 0: a single-node cluster — the same control plane, still run as kube, plus containerd,
#     kubelet and kube-proxy as root, CoreDNS and a ptp CNI network, so Pods run inside this container.
# =====================================================================

# --- kubernetes: the seven binaries, plus the pause container image built from upstream's pause.c ---------------------
FROM golang:1.26.11-bookworm@sha256:dc40a13b61304647ed7e5d581d246b86413dfc29d63c6d018310feb93cd98fc0 AS kubernetes-build
ARG SOURCE_DATE_EPOCH=1795161084
WORKDIR /k8s
COPY vendored/kubernetes-src/ .
ENV CGO_ENABLED=0 GOTOOLCHAIN=local GOFLAGS=-buildvcs=false GOPROXY=off
# upstream hack/lib/golang.sh + version.sh: tags selinux,notest,grpcnotrace; -trimpath -s -w; gitVersion/gitCommit/
# gitTreeState/gitMajor/gitMinor/buildDate stamped into both version packages; buildDate from SOURCE_DATE_EPOCH (the tag
# commit's committer date). All seven are static (CGO_ENABLED=0). go.work + the workspace vendor/ (no network).
RUN V=v1.37.2 C=c50e5395f1ae2d4a2c05f28fdcc38c0916cc1a32 D=2026-10-27T12:01:04Z L="-s -w" && \
    for p in k8s.io/client-go/pkg/version k8s.io/component-base/version; do \
      L="$L -X $p.gitVersion=$V -X $p.gitCommit=$C -X $p.gitTreeState=clean -X $p.gitMajor=1 -X $p.gitMinor=37 -X $p.buildDate=$D"; \
    done && mkdir -p /out && \
    go build -trimpath -tags selinux,notest,grpcnotrace -ldflags "$L" -o /out/ \
      ./cmd/kube-apiserver ./cmd/kube-controller-manager ./cmd/kube-scheduler ./cmd/kubelet ./cmd/kube-proxy \
      ./cmd/kubectl ./cmd/kubeadm && \
    for b in kube-apiserver kube-controller-manager kube-scheduler kubelet kube-proxy; do \
      /out/$b --version | grep -qx 'Kubernetes v1.37.2' || { echo "$b does not report v1.37.2" >&2; exit 1; }; done && \
    /out/kubeadm version -o short | grep -qx 'v1.37.2' && /out/kubectl version --client | grep -q 'Client Version: v1.37.2'
# pause: build/pause/linux/pause.c with the CFLAGS of build/pause/Makefile (TAG 3.10.2), packaged as an OCI image the
# node imports into containerd at start (the sandbox image every Pod needs; never pulled from a registry).
COPY --chmod=0755 mk-pause-oci.sh /usr/local/bin/mk-pause-oci.sh
RUN gcc -Os -Wall -Werror -static -DVERSION=v3.10.2 -o /out/pause build/pause/linux/pause.c && \
    /out/pause -v | grep -q 'v3.10.2' && \
    mk-pause-oci.sh /out/pause /out/pause.oci.tar localhost/kubernetes/pause 3.10.2 "$SOURCE_DATE_EPOCH" && rm /out/pause

# --- containerd v2.4.2 (Makefile: version.Version/Revision/Package; CGO off, so no btrfs snapshotter) -----------------
FROM golang:1.26.11-bookworm@sha256:dc40a13b61304647ed7e5d581d246b86413dfc29d63c6d018310feb93cd98fc0 AS containerd-build
WORKDIR /containerd
COPY vendored/containerd-src/ .
ENV CGO_ENABLED=0 GOTOOLCHAIN=local GOWORK=off GOFLAGS="-mod=vendor -buildvcs=false" GOPROXY=off
RUN P=github.com/containerd/containerd/v2 && mkdir -p /out && \
    go build -trimpath -tags "no_btrfs urfave_cli_no_docs" \
      -ldflags "-s -w -X $P/version.Version=v2.4.2 -X $P/version.Revision=b7a25261e029d68978bbf290df0a62fc819b3c51 -X $P/version.Package=$P" \
      -o /out/ ./cmd/containerd ./cmd/ctr ./cmd/containerd-shim-runc-v2 && \
    /out/containerd --version | grep -q ' v2.4.2 b7a25261e029d68978bbf290df0a62fc819b3c51'

# --- runc v1.5.2 (Makefile: CGO, -buildmode=pie, tags seccomp urfave_cli_no_docs; libpathrs, an optional Rust library,
#     is not built: runc then uses its pure-Go path-safety code) ------------------------------------------------------
FROM golang:1.26.11-bookworm@sha256:dc40a13b61304647ed7e5d581d246b86413dfc29d63c6d018310feb93cd98fc0 AS runc-build
RUN --mount=type=bind,source=vendored/seccomp-debs,target=/tmp/seccomp-debs dpkg -i /tmp/seccomp-debs/*.deb >/dev/null
WORKDIR /runc
COPY vendored/runc-src/ .
ENV CGO_ENABLED=1 GOTOOLCHAIN=local GOWORK=off GOFLAGS="-mod=vendor -buildvcs=false" GOPROXY=off
RUN mkdir -p /out && go build -trimpath -buildmode=pie -tags "seccomp urfave_cli_no_docs" \
      -ldflags "-s -w -X main.gitCommit=v1.5.2-0-g29dd3dc2" -o /out/runc . && \
    /out/runc --version | grep -q '^runc version 1.5.2$' && /out/runc --version | grep -q '^libseccomp: '

# --- CNI plugins v1.9.1 (build_linux.sh: buildversion stamp, CGO off) ---------------------------------------------------
FROM golang:1.26.11-bookworm@sha256:dc40a13b61304647ed7e5d581d246b86413dfc29d63c6d018310feb93cd98fc0 AS cni-build
WORKDIR /cni
COPY vendored/cni-src/ .
ENV CGO_ENABLED=0 GOTOOLCHAIN=local GOWORK=off GOFLAGS="-mod=vendor -buildvcs=false" GOPROXY=off
RUN mkdir -p /out && go build -trimpath \
      -ldflags "-s -w -X github.com/containernetworking/plugins/pkg/utils/buildversion.BuildVersion=v1.9.1" -o /out/ \
      ./plugins/main/bridge ./plugins/main/loopback ./plugins/main/ptp ./plugins/ipam/host-local \
      ./plugins/meta/portmap ./plugins/meta/bandwidth ./plugins/meta/tuning ./plugins/meta/firewall && \
    /out/ptp 2>&1 | grep -q '^CNI ptp plugin v1.9.1$'

# --- crictl v1.37.0 -----------------------------------------------------------------------------------------------------
FROM golang:1.26.11-bookworm@sha256:dc40a13b61304647ed7e5d581d246b86413dfc29d63c6d018310feb93cd98fc0 AS critools-build
WORKDIR /critools
COPY vendored/critools-src/ .
ENV CGO_ENABLED=0 GOTOOLCHAIN=local GOWORK=off GOFLAGS="-mod=vendor -buildvcs=false" GOPROXY=off
RUN mkdir -p /out && go build -trimpath -tags selinux \
      -ldflags "-s -w -X sigs.k8s.io/cri-tools/pkg/version.Version=v1.37.0" -o /out/crictl ./cmd/crictl && \
    /out/crictl --version | grep -q 'v1.37.0'

# --- etcd v3.7.2 (scripts/build_lib.sh: CGO off, GitSHA stamp) -----------------------------------------------------------
FROM golang:1.26.11-bookworm@sha256:dc40a13b61304647ed7e5d581d246b86413dfc29d63c6d018310feb93cd98fc0 AS etcd-build
WORKDIR /etcd
COPY vendored/etcd-src/ .
ENV CGO_ENABLED=0 GOTOOLCHAIN=local GOWORK=off GOFLAGS="-mod=vendor -buildvcs=false" GOPROXY=off
RUN mkdir -p /out && for d in server:etcd etcdctl:etcdctl etcdutl:etcdutl; do \
      ( cd "${d%%:*}" && go build -trimpath -ldflags "-s -w -X go.etcd.io/etcd/api/v3/version.GitSHA=68c065e5" \
        -o "/out/${d##*:}" . ) || exit 1; done && \
    /out/etcd --version | grep -q '^etcd Version: 3.7.2$' && /out/etcdctl version | grep -q '3.7.2'

# --- CoreDNS v1.15.0 (Makefile: CGO off, GitCommit stamp) ---------------------------------------------------------------
FROM golang:1.26.11-bookworm@sha256:dc40a13b61304647ed7e5d581d246b86413dfc29d63c6d018310feb93cd98fc0 AS coredns-build
WORKDIR /coredns
COPY vendored/coredns-src/ .
ENV CGO_ENABLED=0 GOTOOLCHAIN=local GOWORK=off GOFLAGS="-mod=vendor -buildvcs=false" GOPROXY=off
RUN mkdir -p /out && go build -trimpath -ldflags "-s -w -X github.com/coredns/coredns/coremain.GitCommit=a6fde3fe" \
      -o /out/coredns . && /out/coredns -version | grep -q 'CoreDNS-1.15.0'

# --- every Go binary on the pinned toolchain or newer (fail closed on a stale builder) ---------------------------------
FROM golang:1.26.11-bookworm@sha256:dc40a13b61304647ed7e5d581d246b86413dfc29d63c6d018310feb93cd98fc0 AS toolchain-check
COPY --from=kubernetes-build /out/ /chk/
COPY --from=containerd-build /out/ /chk/
COPY --from=runc-build /out/ /chk/
COPY --from=cni-build /out/ /chk/
COPY --from=critools-build /out/ /chk/
COPY --from=etcd-build /out/ /chk/
COPY --from=coredns-build /out/ /chk/
RUN for b in /chk/*; do case "$b" in *.tar) continue ;; esac; \
      v=$(go version "$b" | awk '{print $2}'); \
      [ "$(printf '%s\n%s\n' go1.26.11 "$v" | sort -V | head -n1)" = go1.26.11 ] || \
        { echo "$b was built with '$v', older than the go1.26.11 floor" >&2; exit 1; }; done && \
    echo "toolchain ok: $(ls /chk | wc -l) files" > /toolchain.ok

FROM ubuntu:24.04@sha256:9c7f200c07e3d4a03e7249d2c16bf66a51120fb876aa2242cf31451412543289
ENV DEBIAN_FRONTEND=noninteractive
# Offline apt: dpkg-install the vendored closure (CVE upgrades + runtime packages) with no network. Each pass installs
# one more Pre-Depends level; fail closed unless every vendored package is installed at its vendored version. The
# removed paths are wall-clock or host-derived (dpkg/apt logs, the ldconfig aux-cache).
# vendored/debs: bind-mounted (read-only), so never a layer of the image (kit migration vendored-bind-mount)
RUN --mount=type=bind,source=vendored/debs,target=/tmp/debs \
    set --; for f in /tmp/debs/*.deb; do [ -e "$f" ] && set -- "$@" "$f"; done; \
    for pass in 1 2 3 4 5; do [ $# -eq 0 ] || dpkg -i --skip-same-version "$@" >/dev/null 2>&1 && break; done; \
    dpkg --configure -a && bad= && for d in "$@"; do p=$(dpkg-deb -f "$d" Package) v=$(dpkg-deb -f "$d" Version); \
      case "$(dpkg-query -W -f='${Version} ${db:Status-Abbrev}' "$p" 2>/dev/null)" in "$v ii"*) ;; *) bad="$bad $p=$v" ;; esac; done && \
    { [ -z "$bad" ] || { echo "vendored debs not installed at their vendored version:$bad" >&2; false; }; } && \
    rm -rf /var/lib/apt/lists/* \
           /var/log/dpkg.log /var/log/alternatives.log /var/log/apt \
           /var/cache/ldconfig/aux-cache /var/cache/fontconfig
# Reproducibility: /etc/shadow field 3 is days-since-epoch AT BUILD TIME, so it is frozen to SOURCE_DATE_EPOCH.
# ARG, never ENV: an ENV would persist into the image config and change the digest.
ARG SOURCE_DATE_EPOCH=1795161084
# kube (uid/gid 999) runs the control plane in both modes and owns its state: /var/lib/kubernetes (PKI, etcd data,
# kubeconfigs), /run/kubernetes (this start's generated configs) and /etc/cni/net.d (the CNI network kube-init writes).
RUN groupadd -g 999 kube && useradd -r -u 999 -g kube -d /var/lib/kubernetes -s /usr/sbin/nologin kube && \
    mkdir -p /var/lib/kubernetes /run/kubernetes /etc/cni/net.d /opt/cni/bin /etc/containerd /etc/kubernetes \
             /usr/local/lib/kubernetes /var/lib/containerd /var/lib/kubelet /var/log/pods && \
    chown kube:kube /var/lib/kubernetes /run/kubernetes /etc/cni/net.d && chmod 0700 /var/lib/kubernetes && \
    : "${SOURCE_DATE_EPOCH:?SOURCE_DATE_EPOCH must be set for a reproducible build}" && \
    sed -ri "s/^([^:]*:[^:]*):[0-9]*:/\\1:$((SOURCE_DATE_EPOCH/86400)):/" /etc/shadow && \
    rm -f /etc/passwd- /etc/shadow- /etc/group- /etc/gshadow-
COPY --from=toolchain-check /toolchain.ok /usr/local/lib/kubernetes/toolchain.ok
COPY --from=kubernetes-build /out/kube-apiserver /out/kube-controller-manager /out/kube-scheduler /out/kubelet \
     /out/kube-proxy /out/kubectl /out/kubeadm /usr/local/bin/
COPY --from=kubernetes-build /out/pause.oci.tar /usr/local/lib/kubernetes/pause.oci.tar
COPY --from=containerd-build /out/containerd /out/containerd-shim-runc-v2 /out/ctr /usr/local/bin/
COPY --from=runc-build /out/runc /usr/local/bin/runc
COPY --from=cni-build /out/ /opt/cni/bin/
COPY --from=critools-build /out/crictl /usr/local/bin/crictl
COPY --from=etcd-build /out/etcd /out/etcdctl /out/etcdutl /usr/local/bin/
COPY --from=coredns-build /out/coredns /usr/local/bin/coredns
COPY --chmod=0755 kube-entrypoint.sh kube-svc /usr/local/bin/
COPY --chmod=0644 containerd-config.toml /etc/containerd/config.toml
COPY --chmod=0644 crictl.yaml /etc/crictl.yaml
COPY --chmod=0644 kubelet.yaml kube-proxy.yaml Corefile cluster-rbac.yaml cluster-dns.yaml cni.conflist /etc/kubernetes/
# A bare `supervisorctl status` reads /etc/supervisord.conf first: point it at the configuration this start generated.
RUN ln -s /run/kubernetes/supervisord.conf /etc/supervisord.conf && runc --version >/dev/null
ENV KUBE_VERSION=v1.37.2 KUBECONFIG=/var/lib/kubernetes/admin.conf
HEALTHCHECK --interval=15s --timeout=10s --start-period=120s --retries=3 \
  CMD curl -fsk -o /dev/null https://127.0.0.1:6443/livez || exit 1
EXPOSE 6443
WORKDIR /var/lib/kubernetes
USER 999
ENTRYPOINT ["/usr/local/bin/kube-entrypoint.sh"]
# >>> readystack OCI labels: strategies/kubernetes.json image_labels plus the standard OCI labels,
# the set a generated kit carries (gen_dockerfile.label_lines). Written by scripts/kit_migrations.py;
# scripts/retarget.py re-renders it with every retarget. Never edit it by hand.
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.title="Kubernetes"
LABEL org.opencontainers.image.description="Kubernetes v1.37.2 built from source in one container: a non-root control plane by default, or a single-node cluster that runs Pods when started with --privileged --user 0."
LABEL org.opencontainers.image.source="https://github.com/kubernetes/kubernetes"
LABEL org.opencontainers.image.version="v1.37.2-CE-ubuntu24.04-r4"
LABEL org.opencontainers.image.revision="c50e5395f1ae2d4a2c05f28fdcc38c0916cc1a32"
# <<< readystack OCI labels
