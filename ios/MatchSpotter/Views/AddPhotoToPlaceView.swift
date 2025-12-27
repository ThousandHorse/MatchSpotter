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
    @State private var pendingPhotosData: [String: [(data: Data, location: CLLocation?, takenAt: Date?)]] = [:]
    @State private var shareToFirestore = true
    @ObservedObject private var firebaseManager = FirebaseManager.shared
    @ObservedObject private var storageManager = FirebaseStorageManager.shared
    @State private var uploadErrorMessage: String?
    @State private var uploadErrorDetails: [String] = []

    private let logger = Logger(subsystem: "com.thousandhorse.MatchSpotter", category: "AddPhotoToPlaceView")

    var body: some View {
        NavigationView {
            ZStack {
                formContent
                uploadingOverlay
            }
            .navigationTitle("写真を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .onChange(of: selectedPhotos) { _, newItems in
                Task {
                    await loadPhotosMetadata(from: newItems)
                }
            }
            .alert("アップロードエラー", isPresented: uploadErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                uploadErrorMessageView
            }
            .confirmationDialog(
                "位置情報の確認",
                isPresented: $showingDistanceConfirmation,
                titleVisibility: .visible
            ) {
                confirmationButtons
            } message: {
                Text("選択した写真の撮影場所が、この場所から離れています。この場所で登録してもよろしいですか？")
            }
        }
    }

    // MARK: - View Components

    private var formContent: some View {
        Form {
            photoSelectionSection
            photoInfoSection
            sharingSection
            loadingSection
        }
    }

    private var photoSelectionSection: some View {
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
    }

    private var photoInfoSection: some View {
        Section {
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
    }

    @ViewBuilder
    private var sharingSection: some View {
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
    }

    @ViewBuilder
    private var loadingSection: some View {
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

    private var uploadingOverlay: some View {
        UploadingOverlayView(
            progress: storageManager.uploadProgress,
            isUploading: isLoadingPhotos || storageManager.isUploading
        )
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
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

    private var uploadErrorBinding: Binding<Bool> {
        Binding(
            get: { uploadErrorMessage != nil },
            set: { if !$0 { uploadErrorMessage = nil; uploadErrorDetails = [] } }
        )
    }

    @ViewBuilder
    private var uploadErrorMessageView: some View {
        if let errorMessage = uploadErrorMessage {
            if uploadErrorDetails.isEmpty {
                Text(errorMessage)
            } else {
                Text("\(errorMessage)\n\n詳細:\n\(uploadErrorDetails.joined(separator: "\n"))")
            }
        }
    }

    @ViewBuilder
    private var confirmationButtons: some View {
        Button("この場所で登録") {
            Task {
                await savePhotos()
            }
        }
        Button("キャンセル", role: .cancel) {
            pendingPhotosData.removeAll()
        }
    }

    // MARK: - 写真のメタデータ読み込み
    private func loadPhotosMetadata(from items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }

        isLoadingPhotos = true
        defer { isLoadingPhotos = false }

        pendingPhotosData.removeAll()

        // TaskGroupを使って並列処理
        let photoInfos = await withTaskGroup(of: (identifier: String, data: Data, location: CLLocation?, takenAt: Date?)?.self) { group in
            for item in items {
                group.addTask {
                    let itemIdentifier = item.itemIdentifier ?? UUID().uuidString

                    guard let data = try? await item.loadTransferable(type: Data.self) else {
                        self.logger.error("❌ 画像データの読み込みに失敗: \(itemIdentifier)")
                        return nil
                    }

                    // EXIFExtractorヘルパーを利用してメタデータを抽出
                    let photoLocation = EXIFExtractor.extractLocation(from: data)
                    let takenAt = EXIFExtractor.extractDate(from: data)

                    return (itemIdentifier, data, photoLocation, takenAt)
                }
            }

            var results: [(String, Data, CLLocation?, Date?)] = []
            for await result in group {
                if let result = result {
                    results.append(result)
                }
            }
            return results
        }

        // 結果をpendingPhotosDataに格納
        for (itemIdentifier, data, photoLocation, takenAt) in photoInfos {
            pendingPhotosData[itemIdentifier] = [(data: data, location: photoLocation, takenAt: takenAt)]
        }

        logger.info("📸 \(pendingPhotosData.count)枚の写真メタデータを読み込みました")

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
    }

    // MARK: - 写真の保存処理

    private func savePhotos() async {
        guard !selectedPhotos.isEmpty else {
            logger.warning("⚠️ 選択された写真がありません")
            return
        }

        guard !pendingPhotosData.isEmpty else {
            logger.warning("⚠️ pendingPhotosDataが空です。写真のメタデータ読み込みが完了していない可能性があります")
            uploadErrorMessage = "写真の読み込みに失敗しました。もう一度お試しください。"
            return
        }

        isLoadingPhotos = true
        defer { isLoadingPhotos = false }

        do {
            // ローカルに保存
            var savedCount = 0
            for (_, photosArray) in pendingPhotosData {
                for photoInfo in photosArray {
                    let newPhoto = PhotoData(
                        imageData: photoInfo.data,
                        title: placeName, // お店名を自動設定
                        caption: photoCaption.isEmpty ? nil : photoCaption,
                        takenAt: photoInfo.takenAt ?? Date(), // EXIF日時、なければ現在時刻
                        latitude: photoInfo.location?.coordinate.latitude ?? location.latitude,
                        longitude: photoInfo.location?.coordinate.longitude ?? location.longitude
                    )
                    newPhoto.location = location
                    modelContext.insert(newPhoto)
                    savedCount += 1
                }
            }

            try modelContext.save()
            logger.info("✅ \(savedCount)枚の写真をローカルに保存しました")

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
        guard let userId = firebaseManager.currentUser?.id else {
            uploadErrorMessage = "ユーザー情報の取得に失敗しました"
            return
        }

        // ローカルに保存された写真を取得（未アップロードの写真のみ）
        let localPhotos = location.photos.filter {
            $0.title == placeName && $0.firestoreId == nil
        }

        // TaskGroupを使って並列アップロード
        let results = await withTaskGroup(of: Result<String, Error>.self) { group in
            for photoData in localPhotos {
                group.addTask {
                    do {
                        let uploadedPhoto = try await self.storageManager.uploadPhoto(
                            imageData: photoData.imageData,
                            title: self.placeName, // お店名を自動設定
                            caption: self.photoCaption.isEmpty ? nil : self.photoCaption,
                            latitude: photoData.latitude,
                            longitude: photoData.longitude,
                            locationName: self.location.name,
                            prefectureName: self.location.prefecture?.name,
                            userId: userId,
                            userName: self.firebaseManager.userDisplayName,
                            takenAt: photoData.takenAt
                        )

                        // FirestoreのドキュメントIDをローカルPhotoDataに保存
                        photoData.firestoreId = uploadedPhoto.id
                        self.logger.info("✅ 写真をFirestoreにアップロードしました")
                        return .success(uploadedPhoto.id ?? "N/A")
                    } catch {
                        self.logger.error("❌ Firestoreアップロードエラー: \(error.localizedDescription)")
                        return .failure(error)
                    }
                }
            }

            var uploadResults: [Result<String, Error>] = []
            for await result in group {
                uploadResults.append(result)
            }
            return uploadResults
        }

        // 結果を集計
        var successCount = 0
        var errors: [String] = []
        for result in results {
            switch result {
            case .success(let photoId):
                self.logger.info("✅ 写真をFirestoreにアップロードしました: \(photoId)")
                successCount += 1
            case .failure(let error):
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
