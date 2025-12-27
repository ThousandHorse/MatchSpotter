# MatchSpotter 開発TODOリスト

このドキュメントは、MatchSpotterアプリの今後の開発タスクを優先度順にまとめたものです。

最終更新日: 2025-12-27

---

## 🔴 優先度: 高（Critical）

### 1. いいね機能の完全実装
**現状:** モデルには`likes`と`likedBy`フィールドが存在するが、UI実装が不完全

**必要なタスク:**
- [ ] いいねボタンのUI実装（写真詳細画面）
- [ ] `FirebaseManager`にいいね/いいね解除メソッドを追加
  - `toggleLike(photoId: String, userId: String)`
  - Firestoreトランザクションで`likes`と`likedBy`を更新
- [ ] いいね状態の表示（ハートアイコンの塗りつぶし/空）
- [ ] いいね数のリアルタイム更新
- [ ] Firestoreセキュリティルールの更新（いいね操作の権限設定）

**実装ファイル:**
- `SharedPhotoDetailView.swift`（新規作成）
- `FirebaseManager.swift`
- `firestore.rules`

**優先度理由:** 既にモデル定義があり、SNS機能の基本要素として重要

---

### 2. ユーザープロフィール機能
**現状:** `User`モデルは存在するが、プロフィール画面が未実装

**必要なタスク:**
- [ ] `UserProfileView.swift`の作成
  - ユーザー名、アイコン、統計情報（投稿数、訪問場所数）表示
  - ニックネーム編集機能
  - プロフィール画像アップロード機能
- [ ] `UserService.swift`の拡張
  - ユーザープロフィール更新メソッド
  - プロフィール画像のStorage管理
- [ ] 他ユーザーのプロフィール閲覧機能
  - 写真タップ時にユーザー名をタップ可能に
  - `OtherUserProfileView.swift`の作成
- [ ] 設定タブにプロフィール編集リンクを追加

**実装ファイル:**
- `Views/UserProfileView.swift`（新規）
- `Views/OtherUserProfileView.swift`（新規）
- `Services/UserService.swift`
- `ContentView.swift`（タブ追加）

**優先度理由:** ユーザー識別とコミュニティ形成の基盤

---

### 3. 写真検索・フィルタリング機能
**現状:** `PhotoFilter` enumは定義されているが、UI実装がない

**必要なタスク:**
- [ ] 検索バーの実装（都道府県リスト、場所リスト）
- [ ] フィルタリングUI
  - 期間指定（最近1週間、1ヶ月、3ヶ月、全期間）
  - 投稿者指定（自分のみ、全員、フォロー中）
  - 位置情報の有無
- [ ] `FirebaseManager`の検索メソッド強化
  - テキスト検索（場所名、店名、キャプション）
  - 複合条件検索
  - Algoliaなどの外部検索サービス統合検討
- [ ] 検索履歴の保存（UserDefaults）
- [ ] 人気の検索キーワード表示

**実装ファイル:**
- `Views/SearchView.swift`（新規）
- `Views/FilterOptionsView.swift`（新規）
- `FirebaseManager.swift`（検索メソッド追加）

**優先度理由:** 写真が増えると必須の機能

---

## 🟡 優先度: 中（Important）

### 4. コメント機能
**現状:** 未実装

**必要なタスク:**
- [ ] `Comment`モデルの定義（`FirebaseModels.swift`）
  ```swift
  struct Comment: Codable, Identifiable {
      var id: String?
      var photoId: String
      var userId: String
      var userName: String?
      var text: String
      var createdAt: Date
  }
  ```
- [ ] Firestoreコレクション設計
  - `/sharedPhotos/{photoId}/comments/{commentId}`（サブコレクション）
- [ ] コメント一覧表示UI（写真詳細画面下部）
- [ ] コメント投稿UI（テキストフィールド + 送信ボタン）
- [ ] コメント削除機能（自分のコメントと写真投稿者のみ）
- [ ] コメント数の表示（写真一覧）
- [ ] リアルタイム更新（Firestore Snapshot Listener）
- [ ] Firestoreセキュリティルールの追加

**実装ファイル:**
- `Models/FirebaseModels.swift`
- `Services/CommentService.swift`（新規）
- `Views/CommentListView.swift`（新規）
- `Views/CommentInputView.swift`（新規）
- `firestore.rules`

**優先度理由:** コミュニティ機能の充実に必要

---

### 5. 通知機能
**現状:** 未実装

**必要なタスク:**
- [ ] Firebase Cloud Messaging (FCM) 統合
- [ ] APNs証明書の設定
- [ ] 通知タイプの定義
  - いいね通知
  - コメント通知
  - フォロー通知（将来実装）
- [ ] `NotificationService.swift`の作成
- [ ] 通知一覧画面（`NotificationsView.swift`）
- [ ] 通知バッジ表示
- [ ] プッシュ通知の送信トリガー（Cloud Functions）
- [ ] 通知設定画面（ON/OFF切り替え）

**実装ファイル:**
- `Services/NotificationService.swift`（新規）
- `Views/NotificationsView.swift`（新規）
- `Views/NotificationSettingsView.swift`（新規）
- Firebase Cloud Functions（新規）

**優先度理由:** ユーザーエンゲージメント向上

---

### 6. 写真編集機能
**現状:** 写真は元のままアップロード

**必要なタスク:**
- [ ] 写真トリミング機能
- [ ] フィルター適用（セピア、モノクロ、ビンテージなど）
- [ ] 明るさ・コントラスト調整
- [ ] 写真回転機能
- [ ] `PhotoEditorView.swift`の作成
- [ ] 編集後の画像保存処理
- [ ] 編集履歴の保存（オプション）

**実装ファイル:**
- `Views/PhotoEditorView.swift`（新規）
- `Helpers/ImageEditor.swift`（新規）
- `AddPhotoToPlaceView.swift`（編集機能統合）

**優先度理由:** ユーザーがより良い写真を投稿できる

---

### 7. オフライン対応の強化
**現状:** Firestoreの永続化は有効だが、画像のオフライン対応が不十分

**必要なタスク:**
- [ ] 写真のプリキャッシュ機能
  - よく閲覧する都道府県/場所の写真を事前ダウンロード
- [ ] オフライン時のUI表示改善
  - オフライン状態の視覚的表示
  - 同期待ちインジケーター
- [ ] オフライン時の投稿キュー
  - ネットワーク復帰後の自動アップロード
- [ ] キャッシュサイズ管理の改善
  - ユーザー設定可能な最大キャッシュサイズ
  - 自動クリーンアップの頻度設定

**実装ファイル:**
- `ImageCacheManager.swift`（強化）
- `Services/OfflineQueueManager.swift`（新規）
- `SettingsView.swift`（キャッシュ設定追加）

**優先度理由:** ユーザー体験の向上

---

## 🟢 優先度: 低（Nice to Have）

### 8. フォロー機能
**現状:** 未実装

**必要なタスク:**
- [ ] フォロー/フォロワーモデルの定義
- [ ] フォロー/アンフォローUI
- [ ] フォロー中ユーザーの写真フィード
- [ ] フォロワー一覧/フォロー中一覧
- [ ] Firestoreコレクション設計
  - `/users/{userId}/following/{followedUserId}`
  - `/users/{userId}/followers/{followerUserId}`

**実装ファイル:**
- `Models/FirebaseModels.swift`
- `Services/FollowService.swift`（新規）
- `Views/FollowingListView.swift`（新規）
- `Views/FollowersListView.swift`（新規）

---

### 9. タグ機能
**現状:** 未実装

**必要なタスク:**
- [ ] 写真にタグ追加機能（例: #ラーメン, #絶景, #カフェ）
- [ ] タグ検索機能
- [ ] 人気タグランキング
- [ ] タグクラウド表示
- [ ] `SharedPhoto`モデルに`tags: [String]`フィールド追加

**実装ファイル:**
- `Models/FirebaseModels.swift`
- `Views/TagInputView.swift`（新規）
- `Views/TagSearchView.swift`（新規）

---

### 10. 写真のバッチ操作
**現状:** 個別操作のみ

**必要なタスク:**
- [ ] 複数写真の一括選択
- [ ] 一括削除
- [ ] 一括場所移動
- [ ] 一括アップロード
- [ ] 選択モードUI

**実装ファイル:**
- `PlacePhotosGridView.swift`（選択モード追加）
- `PhotoListView.swift`（選択モード追加）

---

### 11. 統計・分析機能
**現状:** 未実装

**必要なタスク:**
- [ ] 個人統計ダッシュボード
  - 総投稿数、訪問都道府県数、訪問場所数
  - 月別投稿グラフ
  - 最も訪問した都道府県ランキング
- [ ] グローバル統計
  - 人気の場所ランキング
  - 人気の都道府県ランキング
- [ ] `StatisticsView.swift`の作成
- [ ] `StatisticsService.swift`の作成

**実装ファイル:**
- `Views/StatisticsView.swift`（新規）
- `Services/StatisticsService.swift`（新規）

---

### 12. エクスポート機能
**現状:** 未実装

**必要なタスク:**
- [ ] 写真データのエクスポート（JSON形式）
- [ ] 写真の一括ダウンロード（ZIP形式）
- [ ] GPXファイル生成（位置情報の軌跡）
- [ ] CSV形式でのデータエクスポート

**実装ファイル:**
- `Services/ExportService.swift`（新規）
- `Views/ExportView.swift`（新規）

---

### 13. 地図機能の強化
**現状:** 基本的なマーカー表示のみ

**必要なタスク:**
- [ ] マーカーのクラスタリング（近い写真をグループ化）
- [ ] ヒートマップ表示（訪問頻度の可視化）
- [ ] ルート表示（訪問順序の可視化）
- [ ] 地図スタイルの切り替え（標準、衛星、地形）
- [ ] カスタムマーカーアイコン（写真のサムネイル表示）

**実装ファイル:**
- `GoogleMapView.swift`（機能追加）
- `Helpers/MapClusteringHelper.swift`（新規）

---

## 🔧 技術的改善・リファクタリング

### 14. テストカバレッジの向上
**現状:** テストが不十分

**必要なタスク:**
- [ ] ユニットテストの追加
  - モデルのテスト
  - サービス層のテスト（モック使用）
  - ヘルパー関数のテスト
- [ ] UIテストの追加
  - 主要フローのE2Eテスト
  - スナップショットテスト
- [ ] テストカバレッジ80%以上を目標

**実装ファイル:**
- `MatchSpotterTests/`（拡充）
- `MatchSpotterUITests/`（新規）

---

### 15. エラーハンドリングの改善
**現状:** エラー処理が不十分な箇所がある

**必要なタスク:**
- [ ] 統一的なエラー型の定義（`MatchSpotterError`）
- [ ] ユーザーフレンドリーなエラーメッセージ
- [ ] エラートースト/アラートの統一UI
- [ ] リトライ機能（ネットワークエラー時）
- [ ] エラーログの記録（Firebase Crashlytics統合）

**実装ファイル:**
- `Models/MatchSpotterError.swift`（新規）
- `Views/ErrorAlertView.swift`（新規）
- `Services/ErrorLogger.swift`（新規）

---

### 16. パフォーマンス最適化
**現状:** 基本的な最適化は実装済み

**必要なタスク:**
- [ ] 画像の遅延読み込み（LazyVStack/LazyVGrid）
- [ ] サムネイル生成の自動化（Cloud Functions）
- [ ] Firestore複合インデックスの最適化
- [ ] メモリ使用量のプロファイリング
- [ ] 起動時間の最適化

**実装ファイル:**
- 全体的なリファクタリング
- Firebase Cloud Functions（サムネイル生成）

---

### 17. アクセシビリティの改善
**現状:** 基本的なVoiceOver対応のみ

**必要なタスク:**
- [ ] すべての画像に適切なアクセシビリティラベル
- [ ] ボタンのアクセシビリティヒント追加
- [ ] ダイナミックタイプ対応（フォントサイズ調整）
- [ ] ハイコントラストモード対応
- [ ] VoiceOverナビゲーションの最適化

**実装ファイル:**
- 全ビューファイル（アクセシビリティ修飾子追加）

---

### 18. 国際化（i18n）
**現状:** 日本語のみ

**必要なタスク:**
- [ ] 英語対応
- [ ] 多言語対応の基盤構築
- [ ] `Localizable.strings`の整備
- [ ] 日付・時刻のローカライズ
- [ ] 都道府県名の英語対応

**実装ファイル:**
- `Localizable.strings`（ja, en）
- 全ビューファイル（文字列のローカライズ）

---

## 📱 プラットフォーム拡張

### 19. Android版の開発
**現状:** iOS版のみ実装済み

**必要なタスク:**
- [ ] Jetpack Compose UIの実装
- [ ] Room データベースの設計
- [ ] Firebase SDK統合（Android）
- [ ] Google Maps SDK統合（Android）
- [ ] EXIF抽出ライブラリの選定
- [ ] アーキテクチャの設計（MVVM/MVI）

**実装ファイル:**
- `android/`ディレクトリ全体（新規）

---

### 20. ウェブ版の開発
**現状:** 未実装

**必要なタスク:**
- [ ] フレームワークの選定（Next.js / React / Vue）
- [ ] Firebase Web SDK統合
- [ ] レスポンシブデザイン
- [ ] PWA対応（オフライン機能）
- [ ] Google Maps JavaScript API統合

**実装ファイル:**
- `web/`ディレクトリ（新規）

---

## 📊 優先度サマリー

| 優先度 | 機能数 | 主な項目 |
|--------|--------|---------|
| 🔴 高 | 3 | いいね機能、ユーザープロフィール、検索・フィルタリング |
| 🟡 中 | 4 | コメント、通知、写真編集、オフライン強化 |
| 🟢 低 | 6 | フォロー、タグ、統計、エクスポート、地図強化 |
| 🔧 技術 | 5 | テスト、エラーハンドリング、パフォーマンス、アクセシビリティ、i18n |
| 📱 拡張 | 2 | Android版、Web版 |

---

## 🎯 推奨開発順序（フェーズ分け）

### フェーズ1: コア機能の完成（1-2ヶ月）
1. いいね機能の完全実装
2. ユーザープロフィール機能
3. 写真検索・フィルタリング機能

### フェーズ2: コミュニティ機能（1-2ヶ月）
4. コメント機能
5. 通知機能
6. フォロー機能

### フェーズ3: UX向上（1ヶ月）
7. 写真編集機能
8. オフライン対応の強化
9. エラーハンドリングの改善

### フェーズ4: 拡張機能（継続的）
10. タグ機能
11. 統計・分析機能
12. 地図機能の強化

### フェーズ5: 品質向上（継続的）
13. テストカバレッジの向上
14. パフォーマンス最適化
15. アクセシビリティの改善

### フェーズ6: グローバル展開（長期）
16. 国際化（i18n）
17. Android版の開発
18. Web版の開発

---

## 📝 メモ

- 各タスクの詳細な設計は別途設計ドキュメントに記載
- Firebaseのセキュリティルールは機能追加ごとに更新必須
- Cloud Functionsの利用は料金に注意
- 大きな機能はフィーチャーブランチで開発し、PRレビューを経てマージ

---

**次回更新予定:** 各フェーズ開始時に詳細タスクを追加
