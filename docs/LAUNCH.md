# ローンチまでの手順（リリース手順）

**今回のリリース対象: iOS（App Store）のみ**（Android は対象外）

---

## 1. リリース前の最終確認

### 1.1 URL の差し替え
- **利用規約**・**プライバシーポリシー**の URL を本番用に設定する  
  - ファイル: `lib/ui/home/settings_screen.dart`  
  - 定数: `kTermsOfServiceUrl` / `kPrivacyPolicyUrl`  
- プライバシーポリシーはストア申請時にも必須なので、GitHub Pages や自社サイトで公開し、その URL を設定する。

### 1.2 バージョン
- `pubspec.yaml` の `version: 1.0.0+1` を確認（左がストア表示用、右がビルド番号）。

### 1.3 デバッグ要素
- デバッグ用「Freeに戻す」ボタンは `kDebugMode` のときのみ表示されるため、リリースビルドでは非表示で問題なし。

---

## 2. iOS（App Store）のリリース

### 2.1 Apple Developer 登録
- [Apple Developer Program](https://developer.apple.com/programs/) に登録（有料）していること。

### 2.2 Xcode で署名・証明書
1. `ios/Runner.xcworkspace` を Xcode で開く。
2. **Signing & Capabilities** で Team を選択し、**Automatically manage signing** を有効にする。
3. Bundle Identifier が他アプリと重複しないことを確認（例: `com.pizzicato.eiseikanrisha`）。

### 2.3 リリース用 Archive
1. Xcode でデバイスを「Any iOS Device (arm64)」に変更。
2. メニュー **Product** → **Archive**。
3. アーカイブ完了後、**Distribute App** → **App Store Connect** → **Upload**。

（またはコマンドでビルドする場合）

```bash
flutter build ipa
```

- 成果物は `build/ios/ipa/` 付近。Xcode の **Organizer** から同じアーカイブをアップロードしても可。

### 2.4 App Store Connect で申請
1. [App Store Connect](https://appstoreconnect.apple.com/) にログイン。
2. アプリを選択（または新規作成）。Bundle ID は Xcode と一致させる。
3. **App 情報**: 名前・プライバシーポリシー URL・カテゴリなど。
4. **1.0 の準備**で、ビルドを選択・スクリーンショット・説明・キーワードを入力。
5. **審査に提出**。

---

## 3. 用意しておくもの（iOS）

| 項目 | 内容 |
|------|------|
| **プライバシーポリシー URL** | 必ず公開済みの URL（設定画面と App Store の両方で同じもの） |
| **利用規約 URL** | 設定画面で開く用 |
| **アプリアイコン** | 1024×1024（App Store 用） |
| **スクリーンショット** | iPhone 6.7/6.5/5.5 インチなど、App Store の推奨サイズ |
| **短い説明** | 1行程度のキャッチコピー |
| **詳細説明** | 機能・対象者・免責など |

---

## 4. ビルド・確認のコマンド（iOS）

```bash
# 依存関係・クリーンビルド
flutter clean && flutter pub get

# iOS リリース IPA（Mac + Xcode 必須）
flutter build ipa
```

リリースビルドではデバッグ用 UI は出ません。実機で `flutter run --release` やストア用ビルドをインストールして最終動作確認することをおすすめします。

---

## （参考）将来 Android をリリースする場合

- 署名: `keytool` で keystore（.jks）を作成し、`android/key.properties` と `android/app/build.gradle.kts` でリリース署名を設定。
- ビルド: `flutter build appbundle`
- 申請: [Google Play Console](https://play.google.com/console) で AAB をアップロードし、ストア情報・プライバシーポリシー URL 等を入力。
