# xbps-static-builds

Statically-linked, musl-libc [xbps](https://github.com/void-linux/xbps)
binaries, published as GitHub Release artifacts for each supported
architecture. Useful anywhere a fully self-contained xbps is needed:
running on hosts without a working xbps install, bootstrapping into a
Void-style package tree, ad-hoc inspection of `.xbps` archives from a
non-Void distro, etc.

## What it produces

A release tagged `<xbps-version>` (e.g. `0.60.7`) containing one tarball
per supported arch:

```
xbps-0.60.7-x86_64.tar.gz
xbps-0.60.7-aarch64.tar.gz
xbps-0.60.7-armv7l.tar.gz
xbps-0.60.7-armv6l.tar.gz
xbps-0.60.7-i686.tar.gz
xbps-0.60.7-ppc64le.tar.gz
xbps-0.60.7-riscv64.tar.gz
xbps-0.60.7-s390x.tar.gz
SHA256SUMS
```

Each tarball extracts to `bin/` (xbps-install, xbps-query, ...), `lib/`,
`share/`, etc., i.e. the `make DESTDIR=... install` payload of xbps with
the dynamic frontends replaced by their `.static` counterparts. The
binaries are static-PIE linked against musl libc; they have no runtime
shared-library dependencies and run on any Linux of the right CPU arch.

Arch naming follows the build host's `uname -m`, so consumers can pick
the right tarball with no translation. `armel` (armv5), `loongarch64`,
and `mips64el` are not currently covered: there's no Alpine Linux
multi-arch container image for them on Docker Hub. LoongArch may
become possible once Alpine publishes an official `linux/loong64`
image.

## How it works

`.github/workflows/build.yml` runs a fan-out matrix of one job per arch.
Each job:

1. Sets up `binfmt_misc` via `docker/setup-qemu-action` so non-native
   arches can be emulated.
2. Pulls `alpine:latest` for the target platform and runs `build.sh`
   inside it. Alpine is natively musl, so all `-static` packages link
   correctly without a musl-gcc dance.
3. Uploads the resulting tarball + `.sha256` as a workflow artifact.

On a tag push, a final `release` job downloads every artifact, regenerates
a combined `SHA256SUMS`, and publishes a GitHub Release.

## Releasing a new xbps version

1. Tag the commit with the desired xbps version: `git tag 0.60.8 && git push --tags`.
2. The workflow builds all arches in parallel and creates the release.

## Manual one-off build

Use the workflow's `workflow_dispatch` trigger ("Run workflow" in the
Actions tab) and supply an `xbps_version`. No release is published; the
tarballs land as workflow artifacts.

## Reproducing locally

Anyone with Docker + QEMU (`docker run --privileged --rm tonistiigi/binfmt
--install all`) can reproduce a single arch:

```
docker run --rm --platform=linux/arm64 \
    -v "$PWD:/work" -w /work \
    -e XBPS_VERSION=0.60.7 \
    alpine:latest \
    sh /work/build.sh
ls dist/
```
