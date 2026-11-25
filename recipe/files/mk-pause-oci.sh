#!/bin/sh
# mk-pause-oci.sh <pause-binary> <out.tar> <image-name> <tag> <source-date-epoch>
# Writes an OCI image layout (as a tar) holding one image: <pause-binary> at /pause, run as 65535:65535, the shape of
# upstream's registry.k8s.io/pause (build/pause/Dockerfile: FROM scratch, ADD pause, USER 65535:65535,
# ENTRYPOINT ["/pause"]). Deterministic: fixed mtimes and owners, sorted entries, no timestamps in the config.
set -eu
bin=$1 out=$2 name=$3 tag=$4 sde=$5
w=$(mktemp -d); trap 'rm -rf "$w"' EXIT
mkdir -p "$w/root" "$w/oci/blobs/sha256"
cp "$bin" "$w/root/pause"; chmod 0755 "$w/root/pause"
T="tar --sort=name --mtime=@$sde --owner=0 --group=0 --numeric-owner --format=gnu"
$T -C "$w/root" -cf "$w/layer.tar" pause
blob() { d=$(sha256sum "$1" | cut -d' ' -f1); cp "$1" "$w/oci/blobs/sha256/$d"; echo "$d $(stat -c %s "$1")"; }
set -- $(blob "$w/layer.tar"); L=$1 LS=$2
printf '{"architecture":"amd64","os":"linux","config":{"User":"65535:65535","Entrypoint":["/pause"],"WorkingDir":"/"},"rootfs":{"type":"layers","diff_ids":["sha256:%s"]}}' "$L" > "$w/config.json"
set -- $(blob "$w/config.json"); C=$1 CS=$2
printf '{"schemaVersion":2,"mediaType":"application/vnd.oci.image.manifest.v1+json","config":{"mediaType":"application/vnd.oci.image.config.v1+json","digest":"sha256:%s","size":%s},"layers":[{"mediaType":"application/vnd.oci.image.layer.v1.tar","digest":"sha256:%s","size":%s}]}' "$C" "$CS" "$L" "$LS" > "$w/manifest.json"
set -- $(blob "$w/manifest.json"); M=$1 MS=$2
printf '{"schemaVersion":2,"mediaType":"application/vnd.oci.image.index.v1+json","manifests":[{"mediaType":"application/vnd.oci.image.manifest.v1+json","digest":"sha256:%s","size":%s,"platform":{"architecture":"amd64","os":"linux"},"annotations":{"io.containerd.image.name":"%s:%s","org.opencontainers.image.ref.name":"%s"}}]}' "$M" "$MS" "$name" "$tag" "$tag" > "$w/oci/index.json"
printf '{"imageLayoutVersion":"1.0.0"}' > "$w/oci/oci-layout"
$T -C "$w/oci" -cf "$out" .
echo "pause image $name:$tag manifest sha256:$M"
