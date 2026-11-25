#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DISPLAY_NAME="YTMusicDesk"
RAW_VERSION="${APP_VERSION:-1.0.0}"
APP_VERSION="${RAW_VERSION#v}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
UNIVERSAL="${UNIVERSAL:-1}"

DIST_DIR="${ROOT_DIR}/dist"
APP_BUNDLE="${DIST_DIR}/${APP_DISPLAY_NAME}.app"
ARCH_TAG="$([[ "${UNIVERSAL}" == "1" ]] && echo "universal" || uname -m)"

ARTIFACT_BASE="YTMusicDesk-v${APP_VERSION}-macOS-${ARCH_TAG}"
DMG_PATH="${DIST_DIR}/${ARTIFACT_BASE}.dmg"
ZIP_PATH="${DIST_DIR}/${ARTIFACT_BASE}.zip"
CHECKSUM_PATH="${DIST_DIR}/SHA256SUMS.txt"
DMG_STAGE="${DIST_DIR}/.dmg-stage"

cd "${ROOT_DIR}"

APP_VERSION="${APP_VERSION}" BUILD_NUMBER="${BUILD_NUMBER}" UNIVERSAL="${UNIVERSAL}" \
    "${ROOT_DIR}/Scripts/build-app.sh" release

echo "==> Packaging DMG: ${DMG_PATH}..."
rm -rf "${DMG_STAGE}" "${DMG_PATH}" "${ZIP_PATH}" "${CHECKSUM_PATH}"
mkdir -p "${DMG_STAGE}"
cp -R "${APP_BUNDLE}" "${DMG_STAGE}/"
ln -s /Applications "${DMG_STAGE}/Applications"

hdiutil create \
    -volname "${APP_DISPLAY_NAME}" \
    -srcfolder "${DMG_STAGE}" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "${DMG_PATH}"

rm -rf "${DMG_STAGE}"

echo "==> Packaging ZIP: ${ZIP_PATH}..."
ditto -c -k --sequesterRsrc --keepParent "${APP_BUNDLE}" "${ZIP_PATH}"

echo "==> Generating SHA256 checksums..."
(
    cd "${DIST_DIR}"
    shasum -a 256 "$(basename "${DMG_PATH}")" "$(basename "${ZIP_PATH}")" > "${CHECKSUM_PATH}"
)

echo "==> Release artifacts ready:"
ls -lh "${DMG_PATH}" "${ZIP_PATH}" "${CHECKSUM_PATH}"
cat "${CHECKSUM_PATH}"
