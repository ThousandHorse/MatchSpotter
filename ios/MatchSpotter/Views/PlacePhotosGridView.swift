//
//  PlacePhotosGridView.swift
//  MatchSpotter
//
//  お店の写真をグリッド表示するビュー
//

import SwiftUI
import SwiftData
import OSLog

/// お店の写真をグリッド表示するビュー
struct PlacePhotosGridView: View {
    let placeGroup: PlaceGroup
    let unifiedLocation: UnifiedLocation
    var onPhotoDeleted: ((String?) -> Void)?  // 削除時のコールバック
    @Environment(\.dismiss) private var dismiss

    @Environment(\.modelContext) private var modelContext
    @State private var showAddPhotoSheet = false
    @State private var locationForAddPhoto: Location?
    @State private var refreshID = UUID()
    @Query private var allPrefectures: [Prefecture]

    private let logger = Logger(subsystem: "com.thousandhorse.MatchSpotter", category: "PlacePhotosGridView")

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 1),
                GridItem(.flexible(), spacing: 1),
                GridItem(.flexible(), spacing: 1)
            ], spacing: 1) {
                ForEach(placeGroup.photos, id: \.id) { photo in
                    UnifiedPhotoGridItemView(
                        photo: photo,
                        localPhotos: unifiedLocation.localLocation?.photos ?? [],
                        onPhotoDeleted: { photoId in
                            logger.info("🗑️ 写真削除通知を受信: \(photoId ?? "nil")")

                            // 削除コールバックを親に通知
                            onPhotoDeleted?(photoId)

                            // このお店の写真が1枚だけだった場合、削除後は自動で戻る
                            if placeGroup.photos.count == 1 {
                                logger.info("📸 最後の1枚が削除されたため、自動で前の画面に戻ります")
                                dismiss()
                            }
                        }
                    )
                }
            }
        }
        .navigationTitle(placeGroup.placeName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        await handleAddPhotoButtonTap()
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.pink)
                }
            }
        }
        .sheet(item: $locationForAddPhoto, onDismiss: {
            // 写真追加後に画面をリフレッシュ
            refreshID = UUID()
        }) { location in
            AddPhotoToPlaceView(location: location, placeName: placeGroup.placeName)
        }
        .id(refreshID)
    }

    /// 写真追加ボタンがタップされた時の処理
    private func handleAddPhotoButtonTap() async {
        // ローカルの場所が既にある場合は、それを使用
        if let existingLocation = unifiedLocation.localLocation {
            locationForAddPhoto = existingLocation
            logger.debug("✅ 既存のローカルLocationを使用: \(existingLocation.name)")
            return
        }

        // Firestoreのみの場所の場合、ローカルにPrefectureとLocationを作成
        logger.debug("📝 Firestoreのみの場所のため、ローカルにLocation作成: \(unifiedLocation.name)")

        if let newLocation = LocationHelper.getOrCreateLocation(
            prefectureName: unifiedLocation.prefectureName,
            locationName: unifiedLocation.name,
            latitude: unifiedLocation.latitude,
            longitude: unifiedLocation.longitude,
            modelContext: modelContext,
            allPrefectures: allPrefectures
        ) {
            locationForAddPhoto = newLocation
            logger.debug("✅ 新規作成したLocationで写真追加画面を表示")
        } else {
            logger.error("❌ Locationの作成に失敗しました。")
        }
    }
}

#Preview {
    let location = Location(name: "新大久保")
    let unifiedLocation = UnifiedLocation(
        name: "新大久保",
        prefectureName: "東京都",
        localLocation: location,
        photoCount: 2
    )

    let photo1 = SharedPhoto(
        imageURL: "https://example.com/photo1.jpg",
        title: "Place",
        userId: "user1",
        takenAt: Date()
    )

    let photo2 = SharedPhoto(
        imageURL: "https://example.com/photo2.jpg",
        title: "Place",
        userId: "user1",
        takenAt: Date()
    )

    let placeGroup = PlaceGroup(
        placeName: "Place",
        photos: [.shared(photo1), .shared(photo2)]
    )

    return NavigationStack {
        PlacePhotosGridView(placeGroup: placeGroup, unifiedLocation: unifiedLocation)
    }
    .modelContainer(for: [Prefecture.self, Location.self, PhotoData.self], inMemory: true)
}
