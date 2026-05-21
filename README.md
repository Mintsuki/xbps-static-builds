# xbps-static-builds

Statically-linked, musl-libc [xbps](https://github.com/void-linux/xbps)
binaries, published as GitHub Release artifacts for each supported
architecture. Useful anywhere a fully self-contained xbps is needed:
running on hosts without a working xbps install, bootstrapping into a
Void-style package tree, ad-hoc inspection of `.xbps` archives from a
non-Void distro, etc.

## What it produces

Each push to `trunk` (or a manual `workflow_dispatch`) creates a
GitHub Release containing one tarball per supported arch:

```
xbps-static-bin-linux-x86_64.tar.gz
xbps-static-bin-linux-aarch64.tar.gz
xbps-static-bin-linux-armv7l.tar.gz
xbps-static-bin-linux-armv6l.tar.gz
xbps-static-bin-linux-i686.tar.gz
xbps-static-bin-linux-ppc64le.tar.gz
xbps-static-bin-linux-riscv64.tar.gz
xbps-static-bin-linux-s390x.tar.gz
```

The release tag and title are the UTC timestamp of the run (e.g.
`20260521T140000Z`); the release body identifies the xbps version
the tarballs carry (pinned in `build.sh`).

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

`.github/workflows/build.yml` runs in three stages:

1. `prepare` computes the UTC timestamp that will be used as both the
   release tag and the name.
2. `build` is a fan-out matrix of one job per arch. Each job sets up
   `binfmt_misc` via `docker/setup-qemu-action`, pulls `alpine:latest`
   for the target platform, runs `build.sh` inside it, and uploads the
   resulting tarball as a workflow artifact. Alpine is natively musl,
   so all `-static` packages link correctly without a musl-gcc dance.
3. `release` downloads every artifact, tags the commit with the
   timestamp from step 1, and publishes a GitHub Release containing all
   tarballs.

## Releasing a new xbps version

1. Bump `XBPS_VERSION` near the top of `build.sh`.
2. Commit and push to `trunk`.
3. The workflow builds every arch in parallel and creates a new release
   tagged with the run's UTC timestamp; the release body identifies the
   xbps version it carries.

## Reproducing locally

Anyone with Docker + QEMU (`docker run --privileged --rm tonistiigi/binfmt
--install all`) can reproduce a single arch:

```
docker run --rm --platform=linux/arm64 \
    -v "$PWD:/work" -w /work \
    -e ARCH=aarch64 \
    alpine:latest \
    sh /work/build.sh
ls dist/
```
