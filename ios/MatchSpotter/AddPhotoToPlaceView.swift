//
//  AddPhotoToPlaceView.swift
//  MatchSpotter
//
//  お店の写真を追加するビュー（お店名が自動入力される）
//

import SwiftUI
import SwiftData
import PhotosUI
import CoreLocation
import ImageIO
import OSLog

/// お店に写真を追加するビュー（お店名が自動入力）
struct AddPhotoToPlaceView: View {
    let location: Location
    let placeName: String // お店名（自動入力）

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoCaption = ""
    @State private var isLoadingPhotos = false
    @State private var showingDistanceConfirmation = false
    @State private var pendingPhotosData: [String: [(data: Data, location: CLLocation?)]] = [:]
    @State private var shareToFirestore = true
    @StateObject private var firebaseManager = FirebaseManager.shared
    @StateObject private var storageManager = FirebaseStorageManager.shared
    @State private var uploadErrorMessage: String?
    @State private var uploadErrorDetails: [String] = []

    private let logger = Logger(subsystem: "com.thousandhorse.MatchSpotter", category: "AddPhotoToPlaceView")

    var body: some View {
        NavigationView {
            ZStack {
                Form {
                    Section("写真を選択") {
                        PhotosPicker(
                            selection: $selectedPhotos,
                            maxSelectionCount: 10,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            HStack {
                                Label("写真を選択（最大10枚）", systemImage: "photo.on.rectangle.angled")
                                    .foregroundColor(.pink)
                                Spacer()
                                if !selectedPhotos.isEmpty {
                                    Text("\(selectedPhotos.count)枚")
                                        .font(.subheadline)
                                        .foregroundColor(.pink)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.pink.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                        }

                        if !selectedPhotos.isEmpty {
                            Text("✓ \(selectedPhotos.count)枚の写真が選択されています")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }

                    Section {
                        // お店名（固定表示）
                        HStack {
                            Text("お店名")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(placeName)
                                .foregroundColor(.primary)
                        }

                        TextField("詳細（任意）", text: $photoCaption, axis: .vertical)
                            .lineLimit(3...6)

                        if selectedPhotos.count > 1 {
                            Text("ℹ️ このお店名と詳細は、選択した全ての写真に適用されます")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("写真情報")
                    }

                    // Firestore共有オプション
                    if firebaseManager.isAuthenticated {
                        Section {
                            Toggle("他のユーザーと共有", isOn: $shareToFirestore)

                            if shareToFirestore {
                                Text("この写真を他のユーザーと共有します")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } header: {
                            Text("共有設定")
                        }
                    }

                    if isLoadingPhotos {
                        Section {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("写真を処理中...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                }

                // アップロード中のオーバーレイ
                UploadingOverlayView(
                    progress: storageManager.uploadProgress,
                    isUploading: isLoadingPhotos || storageManager.isUploading
                )
            }
            .navigationTitle("写真を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        Task {
                            await savePhotos()
                        }
                    }
                    .disabled(selectedPhotos.isEmpty || isLoadingPhotos || storageManager.isUploading)
                }
            }
            .onChange(of: selectedPhotos) { _, newItems in
                Task {
                    await loadPhotosMetadata(from: newItems)
                }
            }
            .alert("アップロードエラー", isPresented: Binding(
                get: { uploadErrorMessage != nil },
                set: { if !$0 { uploadErrorMessage = nil; uploadErrorDetails = [] } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                if let errorMessage = uploadErrorMessage {
                    if uploadErrorDetails.isEmpty {
                        Text(errorMessage)
                    } else {
                        Text("\(errorMessage)\n\n詳細:\n\(uploadErrorDetails.joined(separator: "\n"))")
                    }
                }
            }
            .confirmationDialog(
                "位置情報の確認",
                isPresented: $showingDistanceConfirmation,
                titleVisibility: .visible
            ) {
                Button("この場所で登録") {
                    Task {
                        await processPendingPhotos()
                    }
                }
                Button("キャンセル", role: .cancel) {
                    pendingPhotosData.removeAll()
                }
            } message: {
                Text("選択した写真の撮影場所が、この場所から離れています。この場所で登録してもよろしいですか？")
            }
        }
    }

    // MARK: - 写真のメタデータ読み込み
    private func loadPhotosMetadata(from items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }

        isLoadingPhotos = true
        defer { isLoadingPhotos = false }

        pendingPhotosData.removeAll()

        for item in items {
            let itemIdentifier = item.itemIdentifier ?? UUID().uuidString

            guard let data = try? await item.loadTransferable(type: Data.self) else {
                logger.error("❌ 画像データの読み込みに失敗: \(itemIdentifier)")
                continue
            }

            // 位置情報を取得
            var photoLocation: CLLocation?
            if let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
               let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any],
               let gpsData = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any],
               let latitude = gpsData[kCGImagePropertyGPSLatitude as String] as? Double,
               let longitude = gpsData[kCGImagePropertyGPSLongitude as String] as? Double,
               let latRef = gpsData[kCGImagePropertyGPSLatitudeRef as String] as? String,
               let lonRef = gpsData[kCGImagePropertyGPSLongitudeRef as String] as? String {

                let finalLatitude = latRef == "S" ? -latitude : latitude
                let finalLongitude = lonRef == "W" ? -longitude : longitude
                photoLocation = CLLocation(latitude: finalLatitude, longitude: finalLongitude)
            }

            if pendingPhotosData[itemIdentifier] == nil {
                pendingPhotosData[itemIdentifier] = []
            }
            pendingPhotosData[itemIdentifier]?.append((data: data, location: photoLocation))
        }

        // 距離チェック
        if let locationCoord = location.coordinate {
            let locationCL = CLLocation(latitude: locationCoord.latitude, longitude: locationCoord.longitude)
            let hasDistantPhoto = pendingPhotosData.values.contains { photosArray in
                photosArray.contains { photo in
                    guard let photoLoc = photo.location else { return false }
                    let distance = locationCL.distance(from: photoLoc)
                    return distance > 500 // 500m以上離れている
                }
            }

            if hasDistantPhoto {
                showingDistanceConfirmation = true
                return
            }
        }

        // 距離が近い、または位置情報がない場合は即座に処理
        await processPendingPhotos()
    }

    // MARK: - 写真の保存処理
    private func processPendingPhotos() async {
        // 処理済みフラグ
    }

    private func savePhotos() async {
        guard !selectedPhotos.isEmpty else { return }

        do {
            // ローカルに保存
            for (_, photosArray) in pendingPhotosData {
                for photoInfo in photosArray {
                    let newPhoto = PhotoData(
                        imageData: photoInfo.data,
                        title: placeName, // お店名を自動設定
                        caption: photoCaption.isEmpty ? nil : photoCaption,
                        takenAt: Date(),
                        latitude: photoInfo.location?.coordinate.latitude ?? location.latitude,
                        longitude: photoInfo.location?.coordinate.longitude ?? location.longitude
                    )
                    newPhoto.location = location
                    modelContext.insert(newPhoto)
                }
            }

            try modelContext.save()
            logger.info("✅ \(pendingPhotosData.count)枚の写真をローカルに保存しました")

            // Firestoreに共有する場合
            if shareToFirestore && firebaseManager.isAuthenticated {
                await uploadToFirestore()
            } else {
                dismiss()
            }
        } catch {
            logger.error("❌ 写真の保存エラー: \(error.localizedDescription)")
            uploadErrorMessage = "写真の保存に失敗しました"
            uploadErrorDetails = [error.localizedDescription]
        }
    }

    // MARK: - Firestoreへのアップロード
    private func uploadToFirestore() async {
        var successCount = 0
        var errors: [String] = []

        guard let userId = firebaseManager.currentUser?.id else {
            uploadErrorMessage = "ユーザー情報の取得に失敗しました"
            return
        }

        // ローカルに保存された写真を取得
        let localPhotos = location.photos.filter { $0.title == placeName }

        for photoData in localPhotos {
            do {
                let uploadedPhoto = try await storageManager.uploadPhoto(
                    imageData: photoData.imageData,
                    title: placeName, // お店名を自動設定
                    caption: photoCaption.isEmpty ? nil : photoCaption,
                    latitude: photoData.latitude,
                    longitude: photoData.longitude,
                    locationName: location.name,
                    prefectureName: location.prefecture?.name,
                    userId: userId,
                    userName: firebaseManager.currentUser?.displayName,
                    takenAt: photoData.takenAt
                )

                // FirestoreのドキュメントIDをローカルPhotoDataに保存
                photoData.firestoreId = uploadedPhoto.id
                successCount += 1
                logger.info("✅ 写真をFirestoreにアップロードしました")
            } catch {
                logger.error("❌ Firestoreアップロードエラー: \(error.localizedDescription)")
                errors.append(error.localizedDescription)
            }
        }

        // 変更を保存
        do {
            try modelContext.save()
        } catch {
            logger.error("❌ firestoreId保存エラー: \(error.localizedDescription)")
        }

        if errors.isEmpty {
            logger.info("✅ 全ての写真をFirestoreにアップロードしました（\(successCount)枚）")
            dismiss()
        } else {
            uploadErrorMessage = "\(successCount)枚の写真をアップロードしましたが、\(errors.count)枚で失敗しました。"
            uploadErrorDetails = errors
        }
    }
}
