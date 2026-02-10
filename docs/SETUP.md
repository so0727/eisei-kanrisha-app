# 他のPCで開発環境を用意する

このリポジトリを別のPCでクローンし、編集・実行できるようにする手順です。

---

## 1. リポジトリをクローンする

```bash
git clone https://github.com/so0727/eisei-kanrisha-app.git
cd eisei-kanrisha-app
```

※ フォルダ名は `eisei-kanrisha-app`（ハイフン）になります。中身は同じプロジェクトです。

---

## 2. 必要なソフトをインストールする

### 共通
- **Flutter SDK**  
  - https://docs.flutter.dev/get-started/install  
  - インストール後、ターミナルで `flutter doctor` を実行して問題がないか確認

### macOS で iOS ビルド・実機実行する場合
- **Xcode**（App Store からインストール）
- Xcode を開き、ライセンスに同意しておく
- ターミナルで `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` を実行（必要な場合）

### Chrome で動かすだけの場合
- **Google Chrome** をインストールしておく

---

## 3. 依存関係を入れる

プロジェクトのフォルダで:

```bash
flutter pub get
```

---

## 4. アプリを動かす

### Chrome で開く
```bash
flutter run -d chrome
```

### iOS シミュレータで開く（Mac + Xcode あり）
```bash
# シミュレータを起動してから
flutter run -d ios
```

### 実機で開く（iPhone をUSB接続）
```bash
flutter run -d <デバイスID>
# デバイスIDは flutter devices で確認
```

---

## 5. 編集する

- **Cursor** や **VS Code** で `eisei-kanrisha-app` フォルダを開いて編集
- **Xcode** で iOS の署名などをする場合は、`ios/Runner.xcworkspace` を開く（`.xcworkspace` を選ぶこと）

---

## 6. 変更を共有する（このPC ⇔ 他のPC）

### このPCで変更したとき（他のPCに反映したい）
```bash
git add .
git commit -m "メッセージ"
git push origin main
```

### 他のPCで最新を取り込む
```bash
git pull origin main
flutter pub get
```

---

## 注意

- **key.properties** や **.jks**（Android 署名）は Git に含めていません。Android をリリースするときは、別のPCでもキーを安全にコピーして設定する必要があります。
- プロジェクトが **Box** などクラウドフォルダにある場合、Git の `.git` とクラウドの同期が競合することがあります。他のPCでは **clone した別フォルダ**（例: ホーム直下や Documents）で作業することをおすすめします。
