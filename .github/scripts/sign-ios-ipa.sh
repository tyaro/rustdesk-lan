#!/bin/bash
# Mac ローカルで RustDesk iOS IPA に署名するスクリプト
# 使用方法: ./sign-ios-ipa.sh <unsigned-ipa> <certificate> <provisioning-profile> <team-id> <bundle-id>

set -e

# パラメータチェック
if [ $# -lt 5 ]; then
    echo "使用方法: $0 <unsigned-ipa> <certificate> <provisioning-profile> <team-id> <bundle-id>"
    echo ""
    echo "例："
    echo "  $0 rustdesk-1.4.6-aarch64.ipa ~/Developer/Certificates.p12 ~/Developer/RustDesk.mobileprovision ABCD1234567 com.rustdesk.rustdesk"
    exit 1
fi

IPA_FILE="$1"
CERTIFICATE="$2"
PROVISIONING_PROFILE="$3"
TEAM_ID="$4"
BUNDLE_ID="$5"

# ファイル存在チェック
if [ ! -f "$IPA_FILE" ]; then
    echo "エラー: IPA ファイルが見つかりません: $IPA_FILE"
    exit 1
fi

if [ ! -f "$CERTIFICATE" ]; then
    echo "エラー: 証明書ファイルが見つかりません: $CERTIFICATE"
    exit 1
fi

if [ ! -f "$PROVISIONING_PROFILE" ]; then
    echo "エラー: プロビジョニングプロファイルが見つかりません: $PROVISIONING_PROFILE"
    exit 1
fi

# 一時ディレクトリ作成
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "📦 IPA を展開中..."
unzip -q "$IPA_FILE" -d "$TEMP_DIR"

# Payload ディレクトリを探す
PAYLOAD_DIR="$TEMP_DIR/Payload"
if [ ! -d "$PAYLOAD_DIR" ]; then
    echo "エラー: Payload ディレクトリが見つかりません"
    exit 1
fi

# App ディレクトリを探す
APP_DIR=$(find "$PAYLOAD_DIR" -name "*.app" | head -1)
if [ -z "$APP_DIR" ]; then
    echo "エラー: .app ディレクトリが見つかりません"
    exit 1
fi

APP_NAME=$(basename "$APP_DIR")
echo "📱 アプリ: $APP_NAME"

# 証明書パスをキーチェーンから取得
echo "🔑 証明書をインポート中..."
CERT_ID=$(security import "$CERTIFICATE" -k ~/Library/Keychains/login.keychain-db -P "" -A 2>&1 | grep "identity" | sed "s/.*\"\(.*\)\".*/\1/" | head -1)

if [ -z "$CERT_ID" ]; then
    # 既に存在する場合はそのまま進める
    echo "⚠️  証明書は既にインポート済みか、パスワードが異なる可能性があります"
    echo "   キーチェーンアクセスで確認してください"
    exit 1
fi

echo "✅ 証明書 ID: $CERT_ID"

# プロビジョニングプロファイルをコピー
echo "📋 プロビジョニングプロファイルを配置中..."
cp "$PROVISIONING_PROFILE" "$APP_DIR/embedded.mobileprovision"

# Info.plist を更新（Bundle ID とチーム ID）
PLIST="$APP_DIR/Info.plist"
if [ -f "$PLIST" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$PLIST" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Set :TeamIdentifierPrefix $TEAM_ID" "$PLIST" 2>/dev/null || true
fi

# 署名対象ファイルを検出
echo "🔏 フレームワークと拡張機能に署名中..."
find "$APP_DIR/Frameworks" -name "*.dylib" -o -name "*.framework" | while read -r framework; do
    if [ -d "$framework" ]; then
        codesign --force --verbose --sign "$CERT_ID" "$framework"
    fi
done

# メインアプリに署名
echo "🔐 メインアプリケーションに署名中..."
codesign --force --verbose --sign "$CERT_ID" \
    --entitlements <(security cms -D -i "$APP_DIR/embedded.mobileprovision" | plutil -convert xml1 - -o -) \
    "$APP_DIR"

# 署名を検証
echo "✔️  署名を検証中..."
codesign -v "$APP_DIR" || exit 1

# 署名済み IPA を再生成
SIGNED_IPA="${IPA_FILE%.ipa}-signed.ipa"
echo "📦 署名済み IPA を生成中..."
cd "$TEMP_DIR"
zip -qr - . > "$SIGNED_IPA"
cd - > /dev/null

echo ""
echo "✅ 署名完了！"
echo "🎉 署名済み IPA: $SIGNED_IPA"
