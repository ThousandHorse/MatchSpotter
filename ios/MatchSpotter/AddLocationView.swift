//
//  AddLocationView.swift
//  MatchSpotter
//
//  Created by 千馬拓磨
//

import SwiftUI
import SwiftData
import PhotosUI
import CoreLocation
import ImageIO
import OSLog

/// 場所追加ビュー - 写真から場所を追加
struct AddLocationView: View {
    let prefecture: Prefecture
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firebaseManager = FirebaseManager.shared
    @StateObject private var storageManager = FirebaseStorageManager.shared
    
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var locationName = ""
    @State private var photoTitle = ""
    @State private var photoCaption = ""
    @State private var isProcessingLocation = false
    @State private var detectedLocation: CLLocation?
    @State private var locationAddress = ""
    @State private var shareToFirebase = true // デフォルトで共有ON（みんなに公開）
    @State private var uploadErrorMessage: String?
    
    private let logger = Logger(subsystem: "com.thousandhorse.MatchSpotter", category: "AddLocationView")
    
    var body: some View {
        NavigationView {
            Form {
                Section("写真を選択") {
                    PhotosPicker(
                        selection: $selectedPhoto,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        if let selectedImageData,
                           let uiImage = UIImage(data: selectedImageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .cornerRadius(10)
                        } else {
                            Label("写真を選択", systemImage: "photo")
                                .foregroundColor(.pink)
                        }
                    }
                }
                
                Section("場所情報") {
                    TextField("撮影場所名（例.新宿、渋谷）", text: $locationName)
                        .textContentType(.name)
                    
                    if !locationAddress.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("📍 位置情報")
                                .font(.headline)
                            Text(locationAddress)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                Section("写真情報") {
                    TextField("お店、またはスポット名（例.カフェ、公園）", text: $photoTitle)
                    TextField("詳細（任意）", text: $photoCaption, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                // Firebase共有設定
                if firebaseManager.isAuthenticated {
                    Section {
                        Toggle("写真を共有する", isOn: $shareToFirebase)
                        
                        if shareToFirebase {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                Text("ONにすると利用者全員が閲覧できるようになります")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("共有設定")
                    }
                }
                
                if isProcessingLocation {
                    Section {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("写真から位置情報を取得中...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("新しい場所")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("追加") {
                        Task {
                            await addLocation()
                        }
                    }
                    .disabled(!canAddLocation || storageManager.isUploading)
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let newValue {
                        await loadSelectedPhoto(newValue)
                    }
                }
            }
            .alert("アップロードに失敗しました", isPresented: Binding(
                get: { uploadErrorMessage != nil },
                set: { if !$0 { uploadErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(uploadErrorMessage ?? "アップロードに失敗しました。もう一度お試しください。")
            }
        }
    }
    
    private var canAddLocation: Bool {
        !locationName.isEmpty &&
        !photoTitle.isEmpty &&
        selectedImageData != nil
    }
    
    // 選択した写真を読み込み、EXIFから位置情報を抽出
    private func loadSelectedPhoto(_ item: PhotosPickerItem) async {
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                selectedImageData = data
                
                // 写真のEXIFデータから位置情報を抽出を試行
                isProcessingLocation = true
                if let location = extractLocationFromPhoto(data) {
                    detectedLocation = location
                    await updateLocationAddress(from: location)
                }
                isProcessingLocation = false
            }
        } catch {
            logger.error("写真の読み込みに失敗: \(error.localizedDescription)")
            isProcessingLocation = false
        }
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
    
    // 場所の住所を更新
    private func updateLocationAddress(from location: CLLocation) async {
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                var components: [String] = []
                
                if let name = placemark.name,
                   !name.isEmpty,
                   !name.hasPrefix(placemark.thoroughfare ?? ""),
                   !name.contains("丁目"),
                   !name.contains("番地") {
                    locationAddress = name
                    return
                }
                
                if let subLocality = placemark.subLocality {
                    components.append(subLocality)
                }
                if let thoroughfare = placemark.thoroughfare {
                    components.append(thoroughfare)
                }
                
                if components.isEmpty, let locality = placemark.locality {
                    components.append(locality)
                }
                
                if components.isEmpty, let administrativeArea = placemark.administrativeArea {
                    components.append(administrativeArea)
                }
                
                locationAddress = components.joined(separator: " ")
                
                if locationAddress.isEmpty {
                    locationAddress = "不明な場所"
                }
            }
        } catch {
            locationAddress = "場所の取得に失敗"
        }
    }
    
    // 場所をデータベースに追加
    private func addLocation() async {
        guard let imageData = selectedImageData else { return }
        uploadErrorMessage = nil
        
        // ローカルデータベースに追加
        let newLocation = Location(
            name: locationName,
            latitude: detectedLocation?.coordinate.latitude,
            longitude: detectedLocation?.coordinate.longitude
        )
        newLocation.prefecture = prefecture
        prefecture.locations.append(newLocation)
        
        let photoData = PhotoData(
            imageData: imageData,
            title: photoTitle,
            caption: photoCaption.isEmpty ? nil : photoCaption,
            latitude: detectedLocation?.coordinate.latitude,
            longitude: detectedLocation?.coordinate.longitude
        )
        photoData.location = newLocation
        newLocation.photos.append(photoData)
        
        modelContext.insert(newLocation)
        modelContext.insert(photoData)
        
        var uploadFailed = false

        // Firebaseに共有する場合
        if shareToFirebase, let userId = firebaseManager.currentUser?.id {
            do {
                logger.debug("🔄 Firebase アップロード開始 - タイトル: \(photoTitle), 場所名: \(locationName), エリア: \(self.prefecture.name), ユーザーID: \(userId)")
                
                let uploadedPhoto = try await storageManager.uploadPhoto(
                    imageData: imageData,
                    title: photoTitle,
                    caption: photoCaption.isEmpty ? nil : photoCaption,
                    latitude: detectedLocation?.coordinate.latitude,
                    longitude: detectedLocation?.coordinate.longitude,
                    locationName: locationName,
                    prefectureName: prefecture.name,
                    userId: userId,
                    userName: firebaseManager.currentUser?.displayName,
                    takenAt: Date()
                )
                
                // FirestoreのドキュメントIDをローカルPhotoDataに保存
                photoData.firestoreId = uploadedPhoto.id
                
                logger.info("✅ Firebaseへのアップロード成功: FirestoreID = \(uploadedPhoto.id ?? "nil")")
            } catch {
                logger.error("❌ Firebaseへのアップロードエラー: \(error.localizedDescription)")
                if let storageError = error as NSError? {
                    logger.error("  Domain: \(storageError.domain), Code: \(storageError.code)")
                }
                uploadErrorMessage = error.localizedDescription
                uploadFailed = true
            }
        }

        if uploadFailed {
            // newLocationを削除すると、カスケード削除ルールにより関連するphotoDataも削除され、Prefectureとのリレーションも自動更新されます。
            modelContext.delete(newLocation)
            return
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            logger.error("❌ ローカルDB保存エラー: \(error.localizedDescription)")
            uploadErrorMessage = "ローカルデータベースへの保存に失敗しました。Firebaseへのアップロードだけが成功している可能性があります。"
        }
    }
}

#Preview {
    let prefecture = Prefecture(name: "東京都")
    return AddLocationView(prefecture: prefecture)
        .modelContainer(for: [Prefecture.self, Location.self, PhotoData.self], inMemory: true)
}
