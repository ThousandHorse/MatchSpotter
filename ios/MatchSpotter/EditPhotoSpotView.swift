//
//  EditPhotoSpotView.swift
//  MatchSpotter
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData
import PhotosUI
import CoreLocation
import CoreLocationUI

/// スポット編集ビュー - 既存の撮影スポット情報を編集
struct EditPhotoSpotView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let spot: PhotoSpot

    @State private var spotName: String = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var newPhotoData: [Data] = []
    @State private var caption = ""
    @State private var locationManager = LocationManager()
    @State private var showDeleteConfirmation = false
    @State private var locationName = ""

    var body: some View {
        NavigationStack {
            Form {
                // スポット名編集
                Section("スポット情報") {
                    TextField("スポット名", text: $spotName)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("📍 位置情報")
                            .font(.headline)
                        if !locationName.isEmpty {
                            Text(locationName)
                                .font(.body)
                                .foregroundColor(.primary)
                        } else {
                            Text("場所を取得中...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // 既存の写真一覧
                Section("登録済みの写真（\(spot.photos.count)枚）") {
                    if spot.photos.isEmpty {
                        Text("写真がありません")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(spot.photos) { photo in
                            HStack {
                                if let uiImage = UIImage(data: photo.imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }

                                VStack(alignment: .leading) {
                                    if let caption = photo.caption {
                                        Text(caption)
                                            .font(.caption)
                                    }
                                    Text(photo.takenAt, style: .date)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: deletePhotos)
                    }
                }

                // 新しい写真を追加
                Section("写真を追加") {
                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: 10,
                        matching: .images
                    ) {
                        Label("写真を選択", systemImage: "photo.on.rectangle.angled")
                    }

                    if !newPhotoData.isEmpty {
                        Text("\(newPhotoData.count)枚の写真を追加予定")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("スポット説明（任意）", text: $caption)
                    }
                }

                // 危険ゾーン
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("このスポットを削除", systemImage: "trash")
                    }
                } header: {
                    Text("危険な操作")
                }
            }
            .navigationTitle("スポットを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveChanges()
                    }
                }
            }
            .onChange(of: selectedPhotos) { _, newValue in
                Task {
                    await loadSelectedPhotos(newValue)
                }
            }
            .onAppear {
                spotName = spot.name
                Task {
                    await updateLocationName()
                }
            }
            .confirmationDialog(
                "本当にこのスポットを削除しますか？",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("削除", role: .destructive) {
                    deleteSpot()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("この操作は取り消せません。スポットに紐づく写真もすべて削除されます。")
            }
        }
    }

    // 選択した写真を読み込み
    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) async {
        newPhotoData = []

        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                newPhotoData.append(data)
            }
        }
    }

    // 写真を削除
    private func deletePhotos(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let photo = spot.photos[index]
                modelContext.delete(photo)
            }
        }
    }

    // 変更を保存
    private func saveChanges() {
        // スポット名を更新
        spot.name = spotName

        // 新しい写真を追加
        for imageData in newPhotoData {
            let photoData = PhotoData(
                imageData: imageData,
                caption: caption.isEmpty ? nil : caption
            )
            photoData.photoSpot = spot
            spot.photos.append(photoData)
            modelContext.insert(photoData)
        }

        // 保存
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("保存エラー: \(error)")
        }
    }

    // 場所名を更新
    private func updateLocationName() async {
        let location = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
        let geocoder = CLGeocoder()

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                var components: [String] = []

                // 優先順位1: お店・施設名（name）
                if let name = placemark.name,
                   !name.isEmpty,
                   // 住所っぽい文字列は除外（数字で始まるものなど）
                   !name.hasPrefix(placemark.thoroughfare ?? ""),
                   !name.contains("丁目"),
                   !name.contains("番地") {
                    locationName = name
                    return
                }

                // 優先順位2: 地区や建物名
                if let subLocality = placemark.subLocality {
                    components.append(subLocality)
                }
                if let thoroughfare = placemark.thoroughfare {
                    components.append(thoroughfare)
                }

                // 優先順位3: 市区町村
                if components.isEmpty, let locality = placemark.locality {
                    components.append(locality)
                }

                // 優先順位4: 都道府県
                if components.isEmpty, let administrativeArea = placemark.administrativeArea {
                    components.append(administrativeArea)
                }

                locationName = components.joined(separator: " ")

                if locationName.isEmpty {
                    locationName = "不明な場所"
                }
            }
        } catch {
            locationName = "場所の取得に失敗"
        }
    }

    // スポットを削除
    private func deleteSpot() {
        modelContext.delete(spot)
        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: PhotoSpot.self, PhotoData.self, configurations: config)

    let spot = PhotoSpot(name: "サンプルスポット", latitude: 35.6895, longitude: 139.7006)
    container.mainContext.insert(spot)

    return EditPhotoSpotView(spot: spot)
        .modelContainer(container)
}
