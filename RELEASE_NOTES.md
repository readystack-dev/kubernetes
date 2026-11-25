# Kubernetes v1.37.2 — ReadyStack release `v1.37.2-CE-ubuntu24.04-r4`

Generated 2026-11-21 from this release's build records and strategy. Statements that come from a single record name it in brackets; the others come from this release's strategy and build log.

## Release

- **Image:** `readystack/kubernetes:v1.37.2-CE-ubuntu24.04-r4` (linux/amd64). Index digest `sha256:4e7adfcde2cd834ddc915f879c1d60b26de01bca3d2fcb6e0566c43ad0c0182f` [`docs/provenance/LOCKED_DIGEST.txt`].
- **Image manifest digest:** `sha256:8e96c66033909e37d0116d6376e20474391c1251dd244745db7c5bca55b69ab5` [`TARGET_DIGEST.txt`].
- **Upstream:** Kubernetes v1.37.2 built from source at `v1.37.2` of https://github.com/kubernetes/kubernetes — upstream notes: https://github.com/kubernetes/kubernetes/releases/tag/v1.37.2 [`docs/provenance/BUILD_RECIPE.json`].
- **Base image:** `ubuntu:24.04`; runtime user `kube`.
- **Build:** `source-rebuild-go`, compiled offline with `--network=none`.
- **Supersedes:** ReadyStack release `v1.37.2-CE-ubuntu24.04-r3`.

## What changed in this release

- Upstream version unchanged (v1.37.2); ReadyStack rebuild.
- Minimum dependency versions ReadyStack enforces on top of upstream (raised only where upstream's own version was lower); shipped versions from the SBOM [`docs/sbom/SBOM.json`]:
  - `golang.org/x/net` raised from upstream's `v0.57.0` to at least `v0.62.0` (shipped: `v0.62.0`)
  - `golang.org/x/crypto` raised from upstream's `v0.54.0` to at least `v0.56.0` (shipped: `v0.58.0`)
  - `golang.org/x/text` raised from upstream's `v0.40.0` to at least `v0.41.0` (shipped: `v0.43.0`)
  - `golang.org/x/mod` raised from upstream's `v0.37.0` to at least `v0.40.0` (shipped: `v0.41.0`)
  - `google.golang.org/grpc` raised from upstream's `v1.82.1` to at least `v1.83.2` (shipped: `v1.83.2`)
  - `go.etcd.io/etcd/client/pkg/v3` raised from upstream's `v3.7.0` to at least `v3.7.2` (shipped: `v3.7.2`)
  - `go.etcd.io/etcd/client/v3` raised from upstream's `v3.7.0` to at least `v3.7.2` (shipped: `v3.7.2`)
  - `go.etcd.io/etcd/api/v3` raised from upstream's `v3.7.0` to at least `v3.7.2` (shipped: `v3.7.2`)
  - `github.com/moby/sys/user` at least `v0.4.1` (shipped: `v0.4.1`)
  - `github.com/klauspost/compress` at least `v1.18.7` (shipped: `v1.20.2`)
- Kubernetes v1.37.2 is unchanged from the release this supersedes (v1.37.2-CE-ubuntu24.04-r3); this release rebuilds it. Changes: the image is rebuilt on the current ubuntu:24.04 image (sha256:9c7f200c07e3…), which its maintainers updated after v1.37.2-CE-ubuntu24.04-r3 was built on sha256:2198e4c65076…. Settings, ports and data volumes are those of v1.37.2-CE-ubuntu24.04-r3: replace the container with this image on the same volumes.

## Security status at release (measured 2026-11-20)

- **Docker Scout:** 0 fixable critical/high vulnerabilities; runs as `999` (non-root); SBOM + provenance attestations present (SPDX SBOM + SLSA v1) [`docs/provenance/SCOUT_VERDICT.json`].
- **OSV cross-check:** no fixable critical/high vulnerability beyond Docker Scout's findings.
- **Signature:** cosign signature verified by ReadyStack's release gate before publishing; check it yourself with `cosign verify --key https://readystack.dev/keys/cosign.pub readystack/kubernetes:v1.37.2-CE-ubuntu24.04-r4` (signatures are recorded in the public Sigstore transparency log).
- **ReadyStack release check at release:** passed (ReadyStack's own test, not a Docker Scout grade). Vulnerabilities are disclosed every day and the image never changes, so it is re-checked daily, beside Docker Scout's own dated grade, at https://readystack.dev/queue.
- **Before exposing this service:** The single-node mode runs with --privileged and root, like every containerised Kubernetes node: a Pod that escapes its container is root in a privileged container. Run workloads you trust, or use the default control-plane mode, which needs neither.
- **Before exposing this service:** admin.conf and super-admin.conf under /var/lib/kubernetes grant full control of the cluster; super-admin.conf is in system:masters and bypasses RBAC. Keep the volume private.
- **Before exposing this service:** Port 6443 is the API server; publish it only where clients need it (-p 127.0.0.1:6443:6443 for local use).

## Reproducibility

Rebuilds offline from this archive to the identical image digest `sha256:8e96c66033909e37d0116d6376e20474391c1251dd244745db7c5bca55b69ab5`: run `./BUILD_OFFLINE.sh`, then `./VERIFY_OFFLINE.sh` (add `--online` to confirm the Docker Hub tag holds the same digest). Before publishing, ReadyStack rebuilt the kit with `./BUILD_OFFLINE.sh` and compared the result with the published digest [`docs/provenance/REPRO_VERIFICATION.json`], then ran `./BUILD_OFFLINE.sh` and `./VERIFY_OFFLINE.sh` from this archive (without `--online`).

## Validation

- 13 of 13 use cases passed (13 authored) against the running image [`docs/validation/test-results.json`].

## Known issues

- None recorded.

## Defects fixed

- 5 problems found before release and fixed before it shipped (5 by review); each is listed in `docs/defects/defects.json`.

## Verify this archive

```
sha256sum -c CHECKSUMS.sha256
./BUILD_OFFLINE.sh && ./VERIFY_OFFLINE.sh --online
cosign verify --key https://readystack.dev/keys/cosign.pub readystack/kubernetes:v1.37.2-CE-ubuntu24.04-r4
```

ReadyStack records every signature in the public Sigstore transparency log (Rekor), so the command needs no extra flags.

