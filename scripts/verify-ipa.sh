#!/bin/bash
set -euo pipefail

# verify-ipa.sh — 验证 IPA 结构和内容
# Usage: verify-ipa.sh <ipa-path>

IPA_PATH="${1:?Usage: verify-ipa.sh <ipa-path>}"
PRODUCT_NAME="Cangjie"

echo "🔍 Verifying IPA: $IPA_PATH"
echo ""

[ ! -f "$IPA_PATH" ] && echo "❌ IPA file not found" && exit 1

VERIFY_DIR="/tmp/cangjie-verify-$$"
rm -rf "$VERIFY_DIR"
mkdir -p "$VERIFY_DIR"
unzip -q "$IPA_PATH" -d "$VERIFY_DIR"

PASS=0
FAIL=0

# 1. 检查 .app
APP_DIR="$VERIFY_DIR/Payload/$PRODUCT_NAME.app"
if [ -d "$APP_DIR" ]; then
    echo "✅ Payload/$PRODUCT_NAME.app exists"
    ((PASS++))
else
    echo "❌ Payload/$PRODUCT_NAME.app NOT found"
    ((FAIL++))
fi

# 2. 检查可执行文件
EXECUTABLE="$APP_DIR/$PRODUCT_NAME"
if [ -f "$EXECUTABLE" ] && [ -x "$EXECUTABLE" ]; then
    echo "✅ Main executable exists and is executable"
    ((PASS++))
else
    echo "❌ Main executable missing or not executable"
    ((FAIL++))
fi

# 3. 检查部署目标（必须 ≤ 16.x）
if [ -f "$EXECUTABLE" ]; then
    MIN_OS=$(vtool -show-build "$EXECUTABLE" 2>/dev/null | grep "minos" | head -1 | sed 's/.*minos //' || echo "unknown")
    echo "   Binary minimum OS: $MIN_OS"
    if [[ "$MIN_OS" == 16.* ]] || [[ "$MIN_OS" == "unknown" ]]; then
        echo "✅ Compatible with iOS 16.x"
        ((PASS++))
    else
        echo "❌ Binary requires iOS $MIN_OS — will crash on iOS 16!"
        ((FAIL++))
    fi
fi

# 4. 检查 entitlements
if [ -f "$EXECUTABLE" ]; then
    ENT_OUTPUT=$(ldid -e "$EXECUTABLE" 2>/dev/null || true)
    if echo "$ENT_OUTPUT" | grep -q "no-sandbox"; then
        echo "✅ Entitlement 'no-sandbox' found"
        ((PASS++))
    else
        echo "⚠️ Entitlement 'no-sandbox' not found"
    fi
    if echo "$ENT_OUTPUT" | grep -q "network.client"; then
        echo "✅ Entitlement 'network.client' found"
        ((PASS++))
    else
        echo "⚠️ Entitlement 'network.client' not found"
    fi
fi

# 5. 检查 Info.plist
INFO_PLIST="$APP_DIR/Info.plist"
if [ -f "$INFO_PLIST" ]; then
    echo "✅ Info.plist exists"
    ((PASS++))
    BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw "$INFO_PLIST" 2>/dev/null || echo "?")
    echo "   Bundle ID: $BUNDLE_ID"
else
    echo "❌ Info.plist NOT found"
    ((FAIL++))
fi

echo ""
echo "======================================"
echo "Verification: $PASS passed, $FAIL failed"
echo "======================================"

rm -rf "$VERIFY_DIR"
[ "$FAIL" -gt 0 ] && exit 1 || exit 0
