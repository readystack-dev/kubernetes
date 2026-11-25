# Kubernetes: ReadyStack build kit

The offline build kit for the Docker image `readystack/kubernetes:v1.37.2-CE-ubuntu24.04-r4`. It holds what the image is built from (upstream source, base images, toolchain, pinned dependencies) and the documents, so the image can be rebuilt with no network access (`docker build --network=none`).

- Release: [v1.37.2-CE-ubuntu24.04-r4](https://github.com/readystack-dev/kubernetes/releases/tag/v1.37.2-CE-ubuntu24.04-r4)
- Image: [`docker.io/readystack/kubernetes:v1.37.2-CE-ubuntu24.04-r4`](https://hub.docker.com/r/readystack/kubernetes/tags), manifest digest `sha256:8e96c66033909e37d0116d6376e20474391c1251dd244745db7c5bca55b69ab5`
- Product page: https://readystack.dev/products/kubernetes
- Source and build recipe: https://readystack.dev/products/kubernetes/recipe
- Build trail: https://readystack.dev/products/kubernetes/trail/v1.37.2-CE-ubuntu24.04-r4
- Defects: this repository's Issues (defects recorded from 25 November 2026 on) and https://readystack.dev/defects.html?product=kubernetes

## The image

One container, two ways to run it. (1) Single-node cluster, started with --privileged --user 0 (the documented run command): etcd, kube-apiserver, kube-controller-manager and kube-scheduler run as the unprivileged user kube; containerd, kubelet and kube-proxy run as root, because a Kubernetes node needs root on Linux; CoreDNS answers cluster DNS and a ptp CNI network gives Pods addresses in 10.244.0.0/24. The node registers as Ready and runs Pods inside this container. (2) Control plane only, the image's default (no --privileged, no --user): etcd, kube-apiserver, kube-controller-manager and kube-scheduler as kube, with no node, so Pods are accepted but stay Pending. The control-plane components run as plain processes under supervisord with the flags kubeadm v1.37 uses; they are not static Pods. One node only: kubeadm join is not run and there is no way to add nodes.

## Who uses Kubernetes and why

Platform and operations teams who run containerised applications across many machines.

Kubernetes is an open-source system for deploying, scaling and managing containerised applications across hosts, with service discovery, load balancing, automated rollouts and rollbacks, and self-healing.

A typical use: A team runs an online shop as several services in containers. In Kubernetes they declare how many copies of each should run; Kubernetes places them on machines, restarts containers that fail, balances traffic between copies, and rolls out a new version step by step, and can roll it back to the previous version.

From the upstream project's own description: https://github.com/kubernetes/kubernetes, https://kubernetes.io/docs/concepts/overview/.

## This release

- Docker Scout policy grade at release: **A** (94%), graded 2026-11-21 with `docker scout policy` (CLI 1.26.0, docker-default configuration).
  - Docker Scout counts 118 packages with copyleft licences (GPL, LGPL, MPL), all of them operating-system packages (it counts only packages whose licence it can read; the SBOM lists every component).
- Signed with ReadyStack's release key (fingerprint `04daa92344a52dbc`): https://readystack.dev/keys/cosign.pub.
- Runs as a non-root user (`999`).
- Attestations on the image: an SPDX SBOM and SLSA provenance v1.
- Rebuilt from this kit with network egress blocked on 2026-11-21; the rebuilt image digest is the published one.
- Base: Ubuntu 24.04.

The current grade, measured again every day, is on https://readystack.dev/products/kubernetes.

Kubernetes is distributed under its upstream licence (Apache-2.0); the kit contains upstream's source under that licence, and each vendored component under its own.

## Download

From the [v1.37.2-CE-ubuntu24.04-r4 release](https://github.com/readystack-dev/kubernetes/releases/tag/v1.37.2-CE-ubuntu24.04-r4): `ReadyStack-kubernetes-v1.37.2-CE-ubuntu24.04-r4.tar.gz` (582.6 MB), SHA-256 `ac5eb73543c5945b9a54d638802571069bce83135cf67d60b96546e5129170b1`.

```sh
sha256sum --check --ignore-missing SHA256SUMS
```

## Verify and rebuild

The rebuild statement is signed with the ReadyStack release key. Check the signature before you rely on it:

```sh
cosign verify-blob --key https://readystack.dev/keys/cosign.pub \
  --bundle ReadyStack-kubernetes-v1.37.2-CE-ubuntu24.04-r4.rebuild.json.sigstore ReadyStack-kubernetes-v1.37.2-CE-ubuntu24.04-r4.rebuild.json
```

Unpack with `-p` so file modes are kept, then follow the kit's own README.md and docs/REBUILD.md:

```sh
tar -xpzf ReadyStack-kubernetes-v1.37.2-CE-ubuntu24.04-r4.tar.gz
cd v1.37.2-CE-ubuntu24.04-r4
less README.md docs/REBUILD.md
```

The build trail (`ReadyStack-kubernetes-v1.37.2-CE-ubuntu24.04-r4.trail.json`, signed the same way, and its Markdown copy) records how this release was built and checked.

## This repository

`recipe/` holds the kit's recipe files (Dockerfiles, build scripts, pins) as published at https://readystack.dev/products/kubernetes/recipe. The complete kit is the release download. Each release is a tag here.

— ReadyStack · https://readystack.dev
