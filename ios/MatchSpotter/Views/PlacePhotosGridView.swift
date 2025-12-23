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
    let onPhotoChanged: () async -> Void // 写真が変更された時のコールバック

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showAddPhotoSheet = false
    @State private var locationForAddPhoto: Location?
    @State private var refreshID = UUID()
    @State private var currentPhotoCount: Int
    @Query private var allPrefectures: [Prefecture]

    private let logger = Logger(subsystem: "com.thousandhorse.MatchSpotter", category: "PlacePhotosGridView")

    init(placeGroup: PlaceGroup, unifiedLocation: UnifiedLocation, onPhotoChanged: @escaping () async -> Void) {
        self.placeGroup = placeGroup
        self.unifiedLocation = unifiedLocation
        self.onPhotoChanged = onPhotoChanged
        self._currentPhotoCount = State(initialValue: placeGroup.photos.count)
    }

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
                        onPhotoDeleted: {
                            await onPhotoChanged()
                            // 写真が削除されたら、写真数をチェック
                            await checkIfShouldDismiss()
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
            Task {
                await onPhotoChanged()
            }
        }) { location in
            AddPhotoToPlaceView(location: location, placeName: placeGroup.placeName)
        }
        .id(refreshID)
        .onDisappear {
            // この画面から離れる時に親ビューをリフレッシュ
            Task {
                await onPhotoChanged()
            }
        }
    }

    /// 写真が空になった場合、自動で前の画面に戻る
    private func checkIfShouldDismiss() async {
        // 少し待ってから写真数をチェック（Firestoreの更新を待つ）
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒待つ

        if placeGroup.photos.isEmpty {
            logger.info("📸 このお店の写真が0件になったため、自動で前の画面に戻ります")
            await MainActor.run {
                dismiss()
            }
        }
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
        PlacePhotosGridView(
            placeGroup: placeGroup,
            unifiedLocation: unifiedLocation,
            onPhotoChanged: {}
        )
    }
    .modelContainer(for: [Prefecture.self, Location.self, PhotoData.self], inMemory: true)
}
