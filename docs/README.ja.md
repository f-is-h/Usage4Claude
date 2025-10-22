# Usage4Claude

[English](../README.md) | [日本語](README.ja.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md)

<div align="center">

<img src="images/icon@2x.png" width="256" alt="icon">

[![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue?style=flat-square)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.0%2B-orange?style=flat-square)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-✓-green?style=flat-square)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/License-MIT-purple?style=flat-square)](LICENSE)
[![Release](https://img.shields.io/github/v/release/f-is-h/Usage4Claude?style=flat-square)](https://github.com/f-is-h/Usage4Claude/releases)

**Claude AI の使用状況をリアルタイムで監視するエレガントな macOS メニューバーアプリ。**

[機能](#-機能) • [インストール](#-インストール) • [使用ガイド](#-使用ガイド) • [よくある質問](#-よくある質問) • [サポート](#-サポート)

</div>

---

## ✨ 機能

### 🎯 コア機能

- **📊 リアルタイム監視** - Claude サブスクリプションの 5 時間使用クォータをメニューバーに表示
- **🎨 スマートカラー** - 使用率に応じた自動色変更（緑/オレンジ/赤）
- **⏰ 正確なタイミング** - 分単位でクォータリセット時間を表示
- **🔄 自動更新** - 設定可能な更新間隔（30秒/1分/5分）
- **💻 ネイティブ体験** - 純粋な macOS ネイティブアプリ、軽量でエレガント

### 🎨 カスタマイズ

- **🕓 複数の表示モード**
  - パーセンテージのみ - シンプルで直感的、クリック不要で確認可能
  - アイコンのみ - 控えめでエレガント、クリックで詳細表示
  - アイコン + パーセンテージ - 完全な情報、素早く視覚的に識別

- **🌍 多言語サポート**
  - English
  - 日本語
  - 简体中文
  - 繁体中文
  - さらに多くの言語に対応予定...

### 🔧 便利な機能

- **⚙️ ビジュアル設定** - コード変更不要、すべてのオプションをGUIで設定
- **🆕 自動更新チェック** - 最新バージョンと機能をタイムリーに取得
- **👋 親切なガイド** - 初回起動時に詳細な設定ウィザード
- **… メニュー表示** - 複数のメニューアクセス方法、詳細ビューと右クリック

### 🔒 セキュリティとプライバシー

- 🏠 **ローカル保存のみ** - すべてのデータはローカルにのみ保存、個人情報の収集・アップロードは一切なし
- 🔐 **Keychain 保護** - 機密情報は Keychain で保護、平文キーなし
- 📖 **オープンソース** - コード完全公開、誰でも監査可能
- 🛡️ **Sandbox 保護** - App Sandbox 有効でセキュリティ強化

---

## 📸 スクリーンショット

### メニューバー表示

| パーセンテージモード | アイコンモード | 組み合わせモード |
|:---:|:---:|:---:|
| <img src="images/taskbar.ring@2x.png" width="20" alt="ring"> | <img src="images/taskbar.icon@2x.png" width="20" alt="icon"> | <img src="images/taskbar@2x.png" width="50" alt="icon and ring"> |

**リングカラーインジケーター**：

🟢 **緑**（0-69%）- 安全に使用中

🟠 **オレンジ**（70-89%）- 使用量に注意

🔴 **赤**（90-100%）- 制限に近づいています

### 詳細ウィンドウ

<img src="images/detail.ja@2x.png" width="290" alt="Detail Window">

### 設定画面

**一般** - 表示、更新、言語オプションをカスタマイズ  
**認証情報** - Claude アカウント認証情報を設定  
**について** - バージョン情報と関連リンク

### ウェルカム画面

**認証情報を設定** - 認証情報設定画面に直接移動して設定を完了  
**後で設定** - ウェルカム画面を閉じて、後で設定画面で設定

---

## 💾 インストール

### 方法1：ビルド済みをダウンロード（推奨）

1. [Releases ページ](https://github.com/f-is-h/Usage4Claude/releases)へ移動
2. 最新バージョンの `.dmg` ファイルをダウンロード
3. ダブルクリックして開き、アプリを「アプリケーション」フォルダにドラッグ
4. 初回起動時は、アプリを右クリックして「開く」を選択（未署名アプリの許可）
5. Keychain での認証情報保存を許可（バージョン更新後は再度許可が必要。認証プロンプトは2回表示：組織 ID、Session Key）

### 方法2：ソースからビルド

#### 必要要件
- macOS 13.0 以降
- Xcode 15.0 以降
- Git

#### ビルド手順

```bash
# リポジトリをクローン
git clone https://github.com/f-is-h/Usage4Claude.git
cd Usage4Claude

# Xcode で開く
open Usage4Claude.xcodeproj

# Xcode で Cmd + R を押して実行
```

---

## 📖 使用ガイド

### 初期設定

1. **アプリを起動**  
   初回実行時にウェルカム画面が表示されます

2. **認証情報を設定**  
   「認証情報の設定へ」ボタンをクリック

3. **必要な情報を取得**  
   - 「ブラウザで Claude 使用量ページを開く」をクリック
   - ブラウザの開発者ツールを開く（F12 または Cmd + Option + I）
   - 「ネットワーク」タブに切り替え
   - ページを更新
   - `usage` という名前のリクエストを見つける
   - ヘッダーを表示し、以下を確認：
     - `Cookie` 内の `sessionKey=sk-ant-...` 値
     - URL 内の組織 ID（形式：`xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`）

4. **情報を入力**  
   - 組織 ID を「Organization ID」フィールドに貼り付け
   - Session Key を「Session Key」フィールドに貼り付け
   - 設定完了後、自動的に監視が開始されます

### 日常使用

- **デフォルト表示** - メニューバーアイコンに使用量パーセンテージを表示
- **詳細を表示** - メニューバーアイコンまたはパーセンテージをクリック
- **メニューを表示** - 詳細ウィンドウの「…」アイコンをクリック、またはメニューバーアイコンを右クリック
- **更新を確認** - メニュー → 更新を確認
- **アプリを終了** - メニュー → 終了

### 更新頻度の推奨

- **30秒** - 使用状況を密接に監視する必要がある場合
- **1分** - 日常使用に推奨（デフォルト）
- **5分** - 低頻度使用、リソース節約

---

## ❓ よくある質問

<details>
<summary><b>Q: アプリが「セッションが期限切れ」と表示される場合は？</b></summary>

A: Session Key は定期的に期限切れになります（通常数週間から数ヶ月）。再取得が必要です：
1. 設定 → 認証情報を開く
2. 設定ガイドに従って新しい Session Key を取得
3. 新しい Session Key を貼り付け

</details>

<details>
<summary><b>Q: 起動時に自動起動するには？</b></summary>

A: 
1. システム設定 → 一般 → ログイン項目を開く
2. 「+」をクリックして Usage4Claude を追加

</details>

<details>
<summary><b>Q: システムリソースの使用量は？</b></summary>

A: 非常に軽量です：
- CPU 使用率：< 0.1%（アイドル時）
- メモリ使用量：約 20MB
- ネットワーク：1分あたり1リクエストのみ

</details>

<details>
<summary><b>Q: サポートされている macOS バージョンは？</b></summary>

A: macOS 13.0 (Ventura) 以降が必要です。Intel と Apple Silicon（M1/M2/M3）チップの両方をサポートしています。

</details>

<details>
<summary><b>Q: なぜ Keychain の許可が必要ですか？</b></summary>

A: 
- Keychain は macOS のシステムレベルパスワードマネージャー
- Session Key と組織 ID は Keychain で暗号化されて保存されます
- これは Apple が推奨する最も安全な機密情報保存方法
- このアプリのみがこの情報にアクセス可能、他のアプリは閲覧不可

</details>

<details>
<summary><b>Q: データは安全ですか？プライバシーはどう保護されていますか？</b></summary>

**完全に安全です！** 

**データ保存：**
- すべてのデータはローカル Mac に**のみ**保存
- 情報の収集、追跡、統計は一切なし
- Claude API 呼び出し以外のネットワークリクエストなし
- サードパーティサービス未使用

**認証情報のセキュリティ：**
- Session Key は macOS Keychain 経由で暗号化（システムレベル暗号化）
- Keychain は AES-256 暗号化 + ハードウェア保護（T2 / Secure Enclave）使用
- このアプリのみが認証情報にアクセス可能、他のアプリは読み取り不可
- 「キーチェーンアクセス」アプリからいつでも権限を取り消し可能

**コードの透明性：**
- 100% オープンソース
- 難読化や隠し機能なし
- コミュニティが監査・検証可能

**追加保護：**
- App Sandbox 有効（システムアクセス制限）
- ファイル、連絡先、他のアプリへのアクセス権限なし
- 最小限の権限（ネットワーク + Keychain のみ）

GitHub でソースコードを確認してこれらすべてを検証できます！

</details>

---

## 🛠 技術スタック

最新の macOS ネイティブ技術で構築：

- **言語**: Swift 5.0+
- **UI フレームワーク**: SwiftUI + AppKit ハイブリッド
- **アーキテクチャ**: MVVM
- **ネットワーク**: URLSession
- **リアクティブ**: Combine Framework
- **ローカライゼーション**: 組み込み i18n サポート
- **プラットフォーム**: macOS 13.0+

---

## 🗺 ロードマップ

### ✅ 完了
- [x] 基本監視機能
- [x] メニューバーリアルタイム表示
- [x] 円形プログレスインジケーター
- [x] スマートカラーアラート
- [x] リアルタイムカウントダウン
- [x] メニューバー複数表示モード
- [x] ビジュアル設定画面
- [x] 多言語サポート
- [x] 初回起動ガイド
- [x] 更新チェック
- [x] 認証情報 Keychain 保存

### 短期計画
1. **機能強化**
    - 🚧 起動時自動起動設定
    - 🚧 キーボードショートカット

2. **開発者向け**
    - 🚧 Shell 自動 DMG パッケージング
    - 🚧 GitHub Actions 自動リリース

### 中期計画
3. **表示の最適化**
    - 設定画面
    - ダークモード
    - 詳細ウィンドウ Focus 状態

5. **機能追加**
    - 7日間使用量監視サポート（OAuth・Opus）
    - 使用量通知
    - より多くの言語ローカライゼーション

### 長期ビジョン
5. **自動セットアップ**

- ブラウザ拡張機能による自動認証
- 認証情報の自動設定

6. **より多くの表示方法**
   - デスクトップウィジェット
   - ブラウザ拡張機能アイコン使用量表示

7. **データ分析**
   - 使用履歴記録
   - トレンドグラフ

8. **マルチプラットフォーム対応**
   - iOS / iPadOS バージョン
   - Apple Watch バージョン
   - Windows バージョン

---

## 🤝 コントリビュート

あらゆる形式のコントリビュートを歓迎します！新機能、バグ修正、ドキュメント改善など。

詳細なコントリビュートガイドラインについては、[CONTRIBUTING.md](../CONTRIBUTING.md) をご覧ください。

### コントリビュート方法

1. このリポジトリをフォーク
2. 機能ブランチを作成 (`git checkout -b feature/AmazingFeature`)
3. 変更をコミット (`git commit -m 'Add some AmazingFeature'`)
4. ブランチにプッシュ (`git push origin feature/AmazingFeature`)
5. プルリクエストを開く

### コントリビューター

このプロジェクトにコントリビュートしてくださったすべての方に感謝します！

<!-- ALL-CONTRIBUTORS-LIST:START -->
<!-- コントリビューターリストは自動生成されます -->
<!-- ALL-CONTRIBUTORS-LIST:END -->

---

## 📝 変更履歴

詳細なバージョン履歴と更新内容については、[CHANGELOG.md](../CHANGELOG.md) をご覧ください。

---

## 💖 サポート

このプロジェクトが役立つ場合は、以下の方法でサポートしてください：

### ⭐ プロジェクトにスター
スターを付けることが最大の励みになります！

### ☕ コーヒーをおごる

<!-- GitHub Sponsors -->
<!-- <a href="https://github.com/sponsors/f-is-h">
  <img src="https://img.shields.io/badge/GitHub-Sponsor-EA4AAA?style=for-the-badge&logo=github" alt="GitHub Sponsor">
</a> -->

<!-- Ko-fi -->
<a href="https://ko-fi.com/1attle">
  <img src="https://img.shields.io/badge/Ko--fi-Support-FF5E5B?style=for-the-badge&logo=ko-fi" alt="Ko-fi">
</a>

<!-- Buy Me A Coffee -->
<!-- <a href="https://buymeacoffee.com/fish_">
  <img src="https://img.shields.io/badge/Buy%20Me%20A%20Coffee-Support-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black" alt="Buy Me A Coffee">
</a> -->

### 📢 プロジェクトを共有
このプロジェクトが気に入ったら、より多くの人に共有してください！

---

## 📄 ライセンス

このプロジェクトは MIT ライセンスの下でライセンスされています - 詳細は [LICENSE](LICENSE) ファイルを参照

```
MIT License

Copyright (c) 2025 f-is-h

ソフトウェアのコピーを自由に使用、コピー、変更、マージ、公開、配布、
サブライセンス、および/または販売できます。
```

---

## 🙏 謝辞

- [Claude AI](https://claude.ai) に感謝 - ほとんどのコードは AI によって書かれました
- すべてのコントリビューターとユーザーのサポートに感謝
- アイコンデザインは Claude AI 公式ブランディングからインスピレーション

---

## 📞 連絡先

- **Issues**: [問題や提案を送信](https://github.com/f-is-h/Usage4Claude/issues)
- **Discussions**: [ディスカッションに参加](https://github.com/f-is-h/Usage4Claude/discussions)
- **GitHub**: [@f-is-h](https://github.com/f-is-h)

---

## ⚖️ 免責事項

このプロジェクトは独立したサードパーティツールであり、Anthropic または Claude AI との公式な関連はありません。このソフトウェアを使用する際は、Claude AI の利用規約を遵守してください。

---

<div align="center">

**このプロジェクトが役立つ場合は、⭐ スターをお願いします！**

Made with ❤️ by [f-is-h](https://github.com/f-is-h)

[⬆ トップに戻る](#usage4claude)

</div> 
