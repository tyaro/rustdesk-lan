# iOS IPA 署名ガイド

このドキュメントでは、GitHub Actions で生成された未署名の iOS IPA ファイルを、Mac ローカルで署名する手順を説明します。

## 前提条件

- macOS 10.15 以上
- Apple Developer Account（Apple Team）
- iOS Development Certificate（.p12形式）
  - Xcode Accounts から自動生成可能
  - または Apple Developer Console から手動作成
- Provisioning Profile（.mobileprovision形式）
  - Apple Developer Console から取得
- Team ID と Bundle ID（Apple Developer Console で確認）

## 手順

### 1. GitHub Release から未署名 IPA をダウンロード

```bash
# 例: v1.4.6-custom-0.1 リリースから rustdesk-1.4.6-aarch64.ipa をダウンロード
cd ~/Downloads
# または gh CLI で:
gh release download v1.4.6-custom-0.1 --pattern "*.ipa"
```

### 2. 証明書とプロビジョニングプロファイルを準備

#### 2.1 Xcode から自動取得（推奨）

```bash
# Xcode にセットアップされた証明書をエクスポート
open -a Xcode
# Preferences → Accounts → Apple ID（Team選択）→ Manage Certificates
# → "+" → iOS Development → Done
```

#### 2.2 Apple Developer Console から手動取得

1. [developer.apple.com](https://developer.apple.com) にログイン
2. **Certificates, Identifiers & Profiles** を開く
3. **Certificates** → iOS Development → ダウンロード（証明書.cer）
4. Keychain Access で .cer から .p12 をエクスポート：
   ```bash
   # Keychain Access で証明書を右クリック
   # → "Export" → .p12形式で保存
   ```
5. **Provisioning Profiles** → iOS App Development → ダウンロード（.mobileprovision）

### 3. 署名スクリプトを実行

```bash
# リポジトリのスクリプトを実行可能にする
chmod +x .github/scripts/sign-ios-ipa.sh

# 署名実行
.github/scripts/sign-ios-ipa.sh \
  ~/Downloads/rustdesk-1.4.6-aarch64.ipa \
  ~/Developer/Certificates.p12 \
  ~/Developer/RustDesk.mobileprovision \
  ABCD1234567 \
  com.rustdesk.rustdesk
```

**パラメータ説明**：
- **第1引数**: 未署名 IPA ファイルパス
- **第2引数**: Developer Certificate (.p12形式)
- **第3引数**: Provisioning Profile (.mobileprovision形式)
- **第4引数**: Apple Team ID（8〜10文字の英数字）
- **第5引数**: Bundle ID（例：`com.rustdesk.rustdesk`）

### 4. Team ID と Bundle ID の確認方法

#### Team ID の確認

```bash
# Xcode で確認
open -a Xcode
# Preferences → Accounts → Team 詳細ページで "(XXXXXX)" の部分

# または Apple Developer Console
# https://developer.apple.com/account → 右上 Team ID
```

#### Bundle ID の確認

リポジトリからの確認：
```bash
grep -r "PRODUCT_BUNDLE_IDENTIFIER" flutter/ios/
# または
cat flutter/Runner.xcodeproj/project.pbxproj | grep PRODUCT_BUNDLE_IDENTIFIER
```

### 5. 署名結果

スクリプト実行後：

```bash
✅ 署名完了！
🎉 署名済み IPA: rustdesk-1.4.6-aarch64-signed.ipa
```

署名済み IPA は `-signed` サフィックス付きで同じディレクトリに生成されます。

## 署名済み IPA の配布

署名済み IPA は以下で配布可能：

### A. 手動アップロード
```bash
# GitHub Release に再度アップロード
gh release upload v1.4.6-custom-0.1 rustdesk-1.4.6-aarch64-signed.ipa
```

### B. TestFlight/App Store へのアップロード
```bash
# Xcode でアップロード
xcrun altool --upload-app --type ios \
  -f rustdesk-1.4.6-aarch64-signed.ipa \
  -u <apple-id> \
  -p <app-specific-password>
```

## トラブルシューティング

### エラー：「Certificate not found」
```bash
# キーチェーン手動確認
security find-identity -v -p codesigning
# Team ID 付きの証明書を確認
```

### エラー：アプリがインストールできない
- Bundle ID が Provisioning Profile と一致しているか確認
- Provisioning Profile の有効期限を確認（Apple Developer Console）
- デバイスの UDID が Provisioning Profile に含まれているか確認

### エラー：Provisioning Profile の署名タイプミスマッチ
- Provisioning Profile を「iOS App Development」または「Ad Hoc」で再作成
- `PRODUCT_BUNDLE_IDENTIFIER` が Provisioning Profile と一致しているか確認

## オートメーション化

CI/CD パイプラインで自動署名したい場合：

```yaml
# .github/secrets 設定
MACOS_CERTIFICATE_P12_BASE64: <Base64エンコードされた .p12>
MACOS_PROVISIONING_PROFILE_BASE64: <Base64エンコードされた .mobileprovision>
MACOS_CERTIFICATE_PASSWORD: <証明書パスワード>
MACOS_TEAM_ID: ABCD1234567
MACOS_BUNDLE_ID: com.rustdesk.rustdesk
```

その場合は、以下の手順で Secrets を設定後、ワークフロー内で署名を実行できます（将来版で実装予定）。

## 参考資料

- [Apple Developer - Signing Your App](https://developer.apple.com/documentation/Xcode/signing-your-app-during-development)
- [iOS Certificate and Provisioning Profile Guide](https://developer.apple.com/support/certificates/)
- [Xcode Build Settings](https://help.apple.com/xcode/mac/current/#/itms15035)
