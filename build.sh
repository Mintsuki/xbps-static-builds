#! /bin/sh
# Build xbps statically against musl, inside an Alpine container that already
# matches the target arch (the CI workflow spins one up per arch via QEMU).
#
# Outputs /work/dist/xbps-${XBPS_VERSION}-${ARCH}.tar.gz, where /work is the
# workflow's checkout mounted in. ARCH must be supplied by the caller (the
# workflow passes the matrix value); uname -m is unreliable here because
# Docker/QEMU report the host kernel's arch for linux/386 and an ARMv7 CPU
# for linux/arm/v6, so deriving the name from uname collides tarballs.

set -eu

: "${XBPS_VERSION:?XBPS_VERSION must be set}"
: "${ARCH:?ARCH must be set}"
OUT_DIR=/work/dist
TARBALL="xbps-${XBPS_VERSION}-${ARCH}.tar.gz"

# Toolchain + every static dep libarchive transitively needs. The exact set
# was derived from `pkg-config --static --libs libarchive` on Alpine; missing
# any one of these fails the .static link step.
apk add --no-cache --quiet \
    build-base pkgconf perl wget file \
    zlib-dev zlib-static \
    xz-dev xz-static \
    zstd-dev zstd-static \
    lz4-dev lz4-static \
    bzip2-dev bzip2-static \
    acl-dev acl-static \
    expat-dev expat-static \
    openssl-dev openssl-libs-static \
    libarchive-dev libarchive-static

mkdir -p /tmp/src
cd /tmp/src
wget -q -O "xbps-${XBPS_VERSION}.tar.gz" \
    "https://github.com/void-linux/xbps/archive/refs/tags/${XBPS_VERSION}.tar.gz"
tar -xzf "xbps-${XBPS_VERSION}.tar.gz"
cd "xbps-${XBPS_VERSION}"

# Force DEBUG=no in the configure script (its default is yes).
sed -i 's/&& DEBUG=yes/&& DEBUG=no/g' configure

CFLAGS="-O2 -pipe -Wno-error" ./configure --verbose --enable-static \
    --prefix=/ --sysconfdir=/etc --localstatedir=/var

make -j"$(nproc)"
make DESTDIR=/tmp/install install

# Drop the dynamic binaries in favour of the static ones (rename .static -> base).
cd /tmp/install/bin
for f in *.static; do
    mv "$f" "${f%.static}"
done

# Strip and sanity-check.
strip -s xbps-* 2>/dev/null || true
for f in xbps-*; do
    if ! file "$f" | grep -qE 'static-pie linked|statically linked'; then
        echo "ERROR: $f is not statically linked:" >&2
        file "$f" >&2
        exit 1
    fi
done

mkdir -p "${OUT_DIR}"
cd /tmp/install
tar -czf "${OUT_DIR}/${TARBALL}" .
( cd "${OUT_DIR}" && sha256sum "${TARBALL}" > "${TARBALL}.sha256" )

echo "Built ${TARBALL}:"
ls -lh "${OUT_DIR}/${TARBALL}"
cat "${OUT_DIR}/${TARBALL}.sha256"
