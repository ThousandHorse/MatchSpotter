//
//  AddPhotoToLocationView.swift
//  MatchSpotter
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData
import PhotosUI
import CoreLocation
import ImageIO

/// 写真追加ビュー - 場所に写真を追加（タイトル・詳細入力）
struct AddPhotoToLocationView: View {
    let location: Location
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoTitle = ""
    @State private var photoCaption = ""
    @State private var isLoadingPhotos = false

    var body: some View {
        NavigationView {
            Form {
                Section("写真を選択") {
                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: 10,
                        matching: .images
                    ) {
                        Label("写真を選択（最大10枚）", systemImage: "photo.on.rectangle.angled")
                            .foregroundColor(.pink)
                    }

                    if !selectedPhotos.isEmpty {
                        Text("\(selectedPhotos.count)枚の写真を選択中")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("写真情報") {
                    TextField("タイトル（必須）", text: $photoTitle)
                    TextField("詳細（任意）", text: $photoCaption, axis: .vertical)
                        .lineLimit(3...6)
                }

                if isLoadingPhotos {
                    Section {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("写真を追加中...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("写真を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        Task {
                            await addPhotos()
                        }
                    }
                    .disabled(selectedPhotos.isEmpty || photoTitle.isEmpty)
                }
            }
        }
    }

    // 写真を追加
    private func addPhotos() async {
        guard !selectedPhotos.isEmpty else { return }

        isLoadingPhotos = true

        for item in selectedPhotos {
            if let data = try? await item.loadTransferable(type: Data.self) {
                // 場所に座標がない場合、最初の写真のEXIF情報から位置情報を取得
                if location.latitude == nil || location.longitude == nil {
                    if let gpsLocation = extractLocationFromPhoto(data) {
                        location.latitude = gpsLocation.coordinate.latitude
                        location.longitude = gpsLocation.coordinate.longitude
                    }
                }

                let photoData = PhotoData(
                    imageData: data,
                    title: photoTitle,
                    caption: photoCaption.isEmpty ? nil : photoCaption
                )
                photoData.location = location
                location.photos.append(photoData)
                modelContext.insert(photoData)
            }
        }

        // 保存
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("写真の保存エラー: \(error)")
        }

        isLoadingPhotos = false
    }

    // EXIFデータから位置情報を抽出
    private func extractLocationFromPhoto(_ imageData: Data) -> CLLocation? {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let gpsInfo = metadata[kCGImagePropertyGPSDictionary as String] as? [String: Any] else {
            return nil
        }

        guard let latitude = gpsInfo[kCGImagePropertyGPSLatitude as String] as? Double,
              let longitude = gpsInfo[kCGImagePropertyGPSLongitude as String] as? Double,
              let latitudeRef = gpsInfo[kCGImagePropertyGPSLatitudeRef as String] as? String,
              let longitudeRef = gpsInfo[kCGImagePropertyGPSLongitudeRef as String] as? String else {
            return nil
        }

        let finalLatitude = latitudeRef == "S" ? -latitude : latitude
        let finalLongitude = longitudeRef == "W" ? -longitude : longitude

        return CLLocation(latitude: finalLatitude, longitude: finalLongitude)
    }
}

#Preview {
    let location = Location(name: "新宿")
    return AddPhotoToLocationView(location: location)
        .modelContainer(for: [Prefecture.self, Location.self, PhotoData.self], inMemory: true)
}
