# Provenance — Kubernetes (`v1.37.2-CE-ubuntu24.04-r4`)

Every item below is copied from a record in this archive; the record is named in brackets.

## Source

- Upstream repository: https://github.com/kubernetes/kubernetes
- Revision built: `v1.37.2` (commit `c50e5395f1ae2d4a2c05f28fdcc38c0916cc1a32`)
- Source tree: `b6f41eac32ed0acabe358cf8afdac9fe0bdf9b38a0950f0f5a258d081acab553` over 31265 files [`docs/provenance/SOURCE_TREE_HASH.json`]
- Community Edition only: enterprise code is removed or refused before the build (CE audit at acquire).

## Build

- Method: `source-rebuild-go`; base image `ubuntu:24.04`
- Compiled with `--network=none` from vendored source, dependencies and base images; BuildKit pinned to `moby/buildkit:v0.31.2` (shipped in `toolchain/`).
- SOURCE_DATE_EPOCH: `1795161084` [`SOURCE_DATE_EPOCH.txt`]
- Frozen inputs: [`docs/provenance/FREEZE_MANIFEST.json`], build recipe: [`docs/provenance/BUILD_RECIPE.json`].

## Output

- Published image: `readystack/kubernetes:v1.37.2-CE-ubuntu24.04-r4` — index digest `sha256:4e7adfcde2cd834ddc915f879c1d60b26de01bca3d2fcb6e0566c43ad0c0182f` [`docs/provenance/LOCKED_DIGEST.txt`]
- linux/amd64 image digest `sha256:8e96c66033909e37d0116d6376e20474391c1251dd244745db7c5bca55b69ab5` — reproduced from this archive before publishing [`docs/provenance/REPRO_VERIFICATION.json`].

## Attestations and signature

- SBOM + SLSA provenance attached to the image: attached: an SPDX SBOM and SLSA v1 provenance [`docs/provenance/SCOUT_VERDICT.json`]
- cosign signature by the ReadyStack release key: verified before publishing. Check it: `cosign verify --key https://readystack.dev/keys/cosign.pub readystack/kubernetes:v1.37.2-CE-ubuntu24.04-r4`

## Pinned inputs, and why

- 44 pinned inputs, each with where it came from, why this one, how it was checked and when it was decided: `docs/PINS.md` [`docs/provenance/PINS.json`] (upstream source 2, base and build images 3, image digests 2, dependency versions readystack sets 10, components from other repositories 7, pins in the kit's dockerfiles 17, readystack's build engine 1, dependencies upstream chose 2).

## Build trail

- How this release passed through the ReadyStack harness, record by record (every chain, drive, stage, review round, defect and check, each naming the record it is copied from): `ReadyStack-kubernetes-v1.37.2-CE-ubuntu24.04-r4.trail.json`, published beside this archive and signed with the release key (`ReadyStack-kubernetes-v1.37.2-CE-ubuntu24.04-r4.trail.json.sigstore`), and readable at https://readystack.dev/products/kubernetes/trail/v1.37.2-CE-ubuntu24.04-r4.

