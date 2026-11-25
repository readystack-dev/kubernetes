# Kubernetes: ReadyStack build kit

The offline build kit for the Docker image `readystack/kubernetes:v1.37.2-CE-ubuntu24.04-r4`. It holds what the image is built from (upstream source, base images, toolchain, pinned dependencies) and the documents, so the image can be rebuilt with no network access (`docker build --network=none`).

- Release: [v1.37.2-CE-ubuntu24.04-r4](https://github.com/readystack-dev/kubernetes/releases/tag/v1.37.2-CE-ubuntu24.04-r4)
- Image: [`docker.io/readystack/kubernetes:v1.37.2-CE-ubuntu24.04-r4`](https://hub.docker.com/r/readystack/kubernetes/tags), manifest digest `sha256:8e96c66033909e37d0116d6376e20474391c1251dd244745db7c5bca55b69ab5`
- Product page: https://readystack.dev/products/kubernetes
- Defects: this repository's Issues (defects recorded from 25 November 2026 on) and https://readystack.dev/defects.html?product=kubernetes

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
