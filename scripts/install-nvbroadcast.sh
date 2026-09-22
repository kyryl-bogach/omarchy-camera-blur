#!/usr/bin/env bash

set -euo pipefail

readonly UPSTREAM_URL="https://github.com/Hkshoonya/nvidia-broadcast-linux.git"
readonly UPSTREAM_COMMIT="328c318fd260e1bea01e87f184023fba69c172c3"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPOSITORY_DIR="$(dirname -- "$SCRIPT_DIR")"
readonly LOCK_FILE="$REPOSITORY_DIR/requirements/nvbroadcast-cuda-py314.lock"
readonly PATCH_FILE="$REPOSITORY_DIR/patches/nvbroadcast-328c318f.patch"

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

if [ "$#" -ne 1 ]; then
    die "Usage: $0 INSTALL_DIRECTORY"
fi

readonly INSTALL_DIRECTORY="$1"

[ "$(uname -s)" = "Linux" ] || die "The lock supports Linux only."
[ "$(uname -m)" = "x86_64" ] || die "The lock supports x86_64 only."
command -v python3.14 >/dev/null || die "Python 3.14 is required."
[ ! -e "$INSTALL_DIRECTORY" ] || die "The install directory already exists: $INSTALL_DIRECTORY"
[ -f "$LOCK_FILE" ] || die "The requirements lock is missing: $LOCK_FILE"
[ -f "$PATCH_FILE" ] || die "The upstream patch is missing: $PATCH_FILE"

git clone --filter=blob:none --no-checkout "$UPSTREAM_URL" "$INSTALL_DIRECTORY"
git -C "$INSTALL_DIRECTORY" fetch --depth=1 origin "$UPSTREAM_COMMIT"
git -C "$INSTALL_DIRECTORY" checkout --detach "$UPSTREAM_COMMIT"

readonly ACTUAL_COMMIT="$(git -C "$INSTALL_DIRECTORY" rev-parse HEAD)"
[ "$ACTUAL_COMMIT" = "$UPSTREAM_COMMIT" ] || die "The upstream commit does not match."

git -C "$INSTALL_DIRECTORY" apply --check --index --unidiff-zero "$PATCH_FILE"
git -C "$INSTALL_DIRECTORY" apply --index --unidiff-zero "$PATCH_FILE"

NVBROADCAST_LOCK_FILE="$LOCK_FILE" \
    "$INSTALL_DIRECTORY/install.sh" --runtime cuda --python "$(command -v python3.14)"
