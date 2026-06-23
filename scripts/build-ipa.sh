#!/bin/bash
set -euo pipefail

# build-ipa.sh — 从 xcarchive 构建 IPA（TrollStore fakesign）
# Usage: build-ipa.sh <xcarchive-path> <output-dir>

ARCHIVE_PATH="${1:?Usage: build-ipa.sh <xcarchive-path> <output-dir>}"
OUTPUT_DIR="${2:?Usage: build-ipa.sh <xcarchive-path> <output-dir>}"
PRODUCT_NAME="Cangjie"
ENTITLEMENTS="Cangjie/Resources/Cangjie.entitlements"

echo "📦 Building IPA from: $ARCHIVE_PATH"

# ── 1. 从 xcarchive 提取 .app ──────────────────────────────────
APP_PATH="$ARCHIVE_PATH/Products/Applications/$PRODUCT_NAME.app"
if [ ! -d "$APP_PATH" ]; then
    echo "❌ .app not found at $APP_PATH"
    echo "Searching for .app in archive..."
    find "$ARCHIVE_PATH" -name "*.app" -type d || true
    exit 1
fi
echo "✅ Found .app at: $APP_PATH"

# ── 2. 创建 IPA 目录结构 ────────────────────────────────────────
rm -rf "$OUTPUT_DIR/ipa"
mkdir -p "$OUTPUT_DIR/ipa/Payload"
cp -r "$APP_PATH" "$OUTPUT_DIR/ipa/Payload/"

# ── 3. Fakesign 主可执行文件（带 entitlements） ─────────────────
EXECUTABLE="$OUTPUT_DIR/ipa/Payload/$PRODUCT_NAME.app/$PRODUCT_NAME"
if [ -f "$EXECUTABLE" ]; then
    codesign --remove-signature "$EXECUTABLE" 2>/dev/null || true

    if [ -f "$ENTITLEMENTS" ]; then
        ldid -S"$ENTITLEMENTS" "$EXECUTABLE"
        echo "✅ Fakesigned main executable with $ENTITLEMENTS"
    else
        echo "⚠️ Entitlements file not found at $ENTITLEMENTS, using ad-hoc sign"
        ldid -S "$EXECUTABLE"
        echo "✅ Fakesigned main executable (ad-hoc)"
    fi
else
    echo "❌ Main executable not found at $EXECUTABLE"
    exit 1
fi

# ── 4. Fakesign 所有 framework 二进制 ──────────────────────────
FW_BASE="$OUTPUT_DIR/ipa/Payload/$PRODUCT_NAME.app/Frameworks"
if [ -d "$FW_BASE" ]; then
    echo ""
    echo "📦 Fakesigning framework binaries..."
    for fw_bundle in "$FW_BASE/"*.framework; do
        [ ! -d "$fw_bundle" ] && continue
        fw_name=$(basename "$fw_bundle" .framework)
        fw_binary="$fw_bundle/$fw_name"
        if [ -f "$fw_binary" ]; then
            codesign --remove-signature "$fw_binary" 2>/dev/null || true
            ldid -S "$fw_binary"
            echo "✅ Fakesigned $fw_name.framework/$fw_name"
        fi
    done

    # 处理 dylib 文件（如果有）
    for dylib in "$FW_BASE/"*.dylib; do
        [ ! -f "$dylib" ] && continue
        dylib_name=$(basename "$dylib")
        codesign --remove-signature "$dylib" 2>/dev/null || true
        ldid -S "$dylib"
        echo "✅ Fakesigned $dylib_name"
    done
fi

# ── 5. 打包 IPA ─────────────────────────────────────────────────
IPA_NAME="$PRODUCT_NAME.ipa"
cd "$OUTPUT_DIR/ipa"
zip -r "$IPA_NAME" Payload
cd -

mkdir -p "$OUTPUT_DIR"
mv "$OUTPUT_DIR/ipa/$IPA_NAME" "$OUTPUT_DIR/"
rm -rf "$OUTPUT_DIR/ipa"

echo ""
echo "✅ IPA created: $OUTPUT_DIR/$IPA_NAME"
ls -lh "$OUTPUT_DIR/$IPA_NAME"
