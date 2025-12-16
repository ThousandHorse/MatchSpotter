//
//  SharedPhotoGroupGridView.swift
//  MatchSpotter
//
//  共有写真グループをグリッド表示するビュー
//

import SwiftUI
import SwiftData
import OSLog

/// 共有写真グループをグリッド表示するビュー
struct SharedPhotoGroupGridView: View {
    let group: SharedPhotoGroup

    @Environment(\.modelContext) private var modelContext
    @State private var showAddPhotoSheet = false
    @State private var locationForAddPhoto: Location?
    @Query private var allPrefectures: [Prefecture]

    private let logger = Logger(subsystem: "com.thousandhorse.MatchSpotter", category: "SharedPhotoGroupGridView")

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 1),
                GridItem(.flexible(), spacing: 1),
                GridItem(.flexible(), spacing: 1)
            ], spacing: 1) {
                ForEach(group.photos, id: \.id) { photo in
                    SharedPhotoGridItemView(photo: photo)
                }
            }
        }
        .navigationTitle(group.locationName)  // お店名がタイトル
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
        .sheet(item: $locationForAddPhoto) { location in
            AddPhotoToPlaceView(location: location, placeName: group.locationName)
        }
    }

    /// 写真追加ボタンタップ時の処理
    private func handleAddPhotoButtonTap() async {
        // ローカルに対応するLocationを探す、なければ作成
        guard let firstPhoto = group.photos.first,
              let prefectureName = firstPhoto.prefectureName else {
            logger.error("❌ 都道府県名が取得できません")
            return
        }

        // 場所名は共有写真のlocationNameを使用（例: 新大久保）
        guard let locationName = firstPhoto.locationName else {
            logger.error("❌ 場所名が取得できません")
            return
        }

        // 既存のPrefectureとLocationを探す
        if let prefecture = allPrefectures.first(where: { $0.name == prefectureName }),
           let existingLocation = prefecture.locations.first(where: { $0.name == locationName }) {
            // 既にローカルにLocationが存在する場合
            locationForAddPhoto = existingLocation
            logger.debug("✅ 既存のLocationを使用: \(locationName)")
            return
        }

        // LocationHelperを使って新しいLocationを作成
        if let newLocation = LocationHelper.getOrCreateLocation(
            prefectureName: prefectureName,
            locationName: locationName,
            latitude: group.latitude,
            longitude: group.longitude,
            modelContext: modelContext,
            allPrefectures: allPrefectures
        ) {
            locationForAddPhoto = newLocation
            logger.debug("✅ 新規Locationを作成: \(locationName)")
        } else {
            logger.error("❌ Location作成失敗")
        }
    }
}

/// 共有写真グリッドアイテム（地図から表示用）
struct SharedPhotoGridItemView: View {
    let photo: SharedPhoto
    @State private var showingDetail = false

    var body: some View {
        Button {
            showingDetail = true
        } label: {
            AsyncImage(url: URL(string: photo.thumbnailURL ?? photo.imageURL)) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(1, contentMode: .fill)
                        .overlay {
                            ProgressView()
                        }

                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        .clipped()
                        .aspectRatio(1, contentMode: .fill)

                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(1, contentMode: .fill)
                        .overlay {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.red)
                        }

                @unknown default:
                    EmptyView()
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            SharedPhotoDetailView(photo: photo)
        }
    }
}
