# MatchSpotter - Android版

## 状態
🚧 **開発予定** - このディレクトリは将来のAndroid版実装のために予約されています。

## 予定される技術スタック

### プラットフォーム
- Android 8.0 (API Level 26) 以上
- Kotlin 1.9+
- Android Studio Hedgehog以上

### 主要フレームワーク・ライブラリ
- **Jetpack Compose** - 宣言的UIフレームワーク
- **Room Database** - データ永続化
- **Google Maps SDK for Android** - 地図表示
- **ExifInterface** - EXIF画像メタデータの読み取り
- **Coroutines & Flow** - 非同期処理
- **Hilt** - 依存性注入
- **Coil** - 画像読み込み

### アーキテクチャ
- MVVM (Model-View-ViewModel)
- Repository Pattern
- Single Activity Architecture
- Jetpack Navigation Compose

## 予定されるプロジェクト構造

```
android/
├── app/
│   ├── src/
│   │   ├── main/
│   │   │   ├── java/com/thousandhorse/matchspotter/
│   │   │   │   ├── ui/
│   │   │   │   │   ├── screens/
│   │   │   │   │   │   ├── MapScreen.kt
│   │   │   │   │   │   ├── SpotListScreen.kt
│   │   │   │   │   │   ├── SpotDetailScreen.kt
│   │   │   │   │   │   ├── AddSpotScreen.kt
│   │   │   │   │   │   └── EditSpotScreen.kt
│   │   │   │   │   ├── components/
│   │   │   │   │   └── theme/
│   │   │   │   ├── data/
│   │   │   │   │   ├── database/
│   │   │   │   │   │   ├── PhotoSpotDao.kt
│   │   │   │   │   │   ├── PhotoDataDao.kt
│   │   │   │   │   │   └── AppDatabase.kt
│   │   │   │   │   ├── model/
│   │   │   │   │   │   ├── PhotoSpot.kt
│   │   │   │   │   │   └── PhotoData.kt
│   │   │   │   │   └── repository/
│   │   │   │   ├── viewmodel/
│   │   │   │   └── util/
│   │   │   │       ├── ExifUtils.kt
│   │   │   │       └── LocationUtils.kt
│   │   │   ├── res/
│   │   │   └── AndroidManifest.xml
│   │   └── test/
│   └── build.gradle.kts
├── gradle/
├── build.gradle.kts
├── settings.gradle.kts
└── README_Android.md
```

## 予定される機能

### 📷 写真スポット登録
- ギャラリーから写真を選択
- 写真のEXIFデータからGPS位置情報を自動抽出
- 逆ジオコーディングで場所名を自動取得
- 現在地からの手動登録

### 🗺️ 地図表示
- Google Maps SDKを使用した地図表示
- カスタムマーカーでスポットを表示
- マーカータップで詳細表示
- 現在地表示、ズーム、回転など

### 📋 リスト表示
- LazyColumnでスポット一覧を表示
- サムネイル画像付き
- スワイプで編集・削除

### ✏️ スポット管理
- スポット情報の編集
- 写真の追加・削除
- スポットの削除

## 必要な権限

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<!-- Android 12以下の場合 -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />
```

## Google Maps API Key設定

`AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_API_KEY_HERE" />
```

または、`local.properties`:
```properties
MAPS_API_KEY=YOUR_API_KEY_HERE
```

## データモデル（Room）

### PhotoSpot Entity
```kotlin
@Entity(tableName = "photo_spots")
data class PhotoSpot(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val name: String,
    val latitude: Double,
    val longitude: Double,
    val createdAt: Long = System.currentTimeMillis()
)
```

### PhotoData Entity
```kotlin
@Entity(
    tableName = "photo_data",
    foreignKeys = [ForeignKey(
        entity = PhotoSpot::class,
        parentColumns = ["id"],
        childColumns = ["spotId"],
        onDelete = ForeignKey.CASCADE
    )]
)
data class PhotoData(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val spotId: Long,
    @ColumnInfo(typeAffinity = ColumnInfo.BLOB)
    val imageData: ByteArray,
    val caption: String? = null,
    val takenAt: Long = System.currentTimeMillis()
)
```

## iOS版との互換性

データモデルはiOS版と互換性があるように設計される予定です。将来的にクラウド同期を実装する際、両プラットフォーム間でデータ共有が可能になります。

## 開発予定スケジュール

- **Phase 1**: プロジェクトセットアップ（2週間）
- **Phase 2**: データレイヤー実装（1週間）
- **Phase 3**: UI実装（3週間）
- **Phase 4**: Google Maps統合（1週間）
- **Phase 5**: テスト・バグ修正（1週間）

## コントリビューション

Android版の開発に興味がある方は、ぜひご協力ください！

## 参考リンク

- [Jetpack Compose](https://developer.android.com/jetpack/compose)
- [Room Database](https://developer.android.com/training/data-storage/room)
- [Google Maps SDK for Android](https://developers.google.com/maps/documentation/android-sdk)
- [ExifInterface](https://developer.android.com/reference/androidx/exifinterface/media/ExifInterface)
