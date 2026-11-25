#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT_DIR}"

DEV_DIR="$(xcode-select -p 2>/dev/null || true)"

if [[ "${DEV_DIR}" == "/Library/Developer/CommandLineTools" ]]; then
    CLT_FRAMEWORKS="${DEV_DIR}/Library/Developer/Frameworks"
    swift test \
        --disable-xctest \
        -Xswiftc -F -Xswiftc "${CLT_FRAMEWORKS}" \
        -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays \
        -Xlinker -F -Xlinker "${CLT_FRAMEWORKS}" \
        -Xlinker -rpath -Xlinker "${CLT_FRAMEWORKS}"
else
    swift test
fi
