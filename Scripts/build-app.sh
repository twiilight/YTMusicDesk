#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DISPLAY_NAME="YTMusicDesk"
EXECUTABLE_NAME="YTMusicDesk"
BUNDLE_ID="com.ytmusicdesk.app"
APP_VERSION="${APP_VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
UNIVERSAL="${UNIVERSAL:-0}"
CONFIG="${1:-release}"

DIST_DIR="${ROOT_DIR}/dist"
APP_BUNDLE="${DIST_DIR}/${APP_DISPLAY_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
ICONSET_DIR="${DIST_DIR}/AppIcon.iconset"

cd "${ROOT_DIR}"

if [[ "${UNIVERSAL}" == "1" ]]; then
    echo "==> Building ${EXECUTABLE_NAME} (${CONFIG}, universal arm64 + x86_64)..."
    swift build -c "${CONFIG}" --triple arm64-apple-macosx
    swift build -c "${CONFIG}" --triple x86_64-apple-macosx
    ARM64_BIN="$(swift build -c "${CONFIG}" --triple arm64-apple-macosx --show-bin-path)/${EXECUTABLE_NAME}"
    X86_64_BIN="$(swift build -c "${CONFIG}" --triple x86_64-apple-macosx --show-bin-path)/${EXECUTABLE_NAME}"
    mkdir -p "${DIST_DIR}"
    BUILT_BINARY="${DIST_DIR}/.${EXECUTABLE_NAME}-universal"
    lipo -create "${ARM64_BIN}" "${X86_64_BIN}" -output "${BUILT_BINARY}"
else
    echo "==> Building ${EXECUTABLE_NAME} (${CONFIG})..."
    swift build -c "${CONFIG}"
    BIN_DIR="$(swift build -c "${CONFIG}" --show-bin-path)"
    BUILT_BINARY="${BIN_DIR}/${EXECUTABLE_NAME}"
fi

if [[ ! -f "${BUILT_BINARY}" ]]; then
    echo "Error: compiled binary not found at ${BUILT_BINARY}" >&2
    exit 1
fi

echo "==> Generating macOS app icon..."
rm -rf "${ICONSET_DIR}" "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"
swift "${ROOT_DIR}/Scripts/generate-icon.swift" "${ICONSET_DIR}"
iconutil -c icns "${ICONSET_DIR}" -o "${RESOURCES_DIR}/AppIcon.icns"
rm -rf "${ICONSET_DIR}"

echo "==> Assembling ${APP_BUNDLE} (v${APP_VERSION})..."
cp "${BUILT_BINARY}" "${MACOS_DIR}/${EXECUTABLE_NAME}"
chmod +x "${MACOS_DIR}/${EXECUTABLE_NAME}"
if [[ "${UNIVERSAL}" == "1" ]]; then
    rm -f "${BUILT_BINARY}"
fi

cat > "${CONTENTS_DIR}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>zh-Hans</string>
        <string>en</string>
    </array>
    <key>CFBundleDisplayName</key>
    <string>${APP_DISPLAY_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>${EXECUTABLE_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_DISPLAY_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.music</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

echo "==> Ad-hoc code signing bundle..."
codesign --force --deep --sign - "${APP_BUNDLE}"
codesign --verify --deep --strict "${APP_BUNDLE}"

echo "==> Architectures:"
lipo -info "${MACOS_DIR}/${EXECUTABLE_NAME}"
echo "==> Done: ${APP_BUNDLE}"
