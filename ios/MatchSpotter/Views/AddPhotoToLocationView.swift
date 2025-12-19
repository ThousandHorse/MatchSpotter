//
//  AddPhotoToLocationView.swift
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

/// 写真追加ビュー - 場所に写真を追加（タイトル・詳細入力）
struct AddPhotoToLocationView: View {
    let location: Location
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoTitle = ""
    @State private var photoCaption = ""
    @State private var isLoadingPhotos = false
    @State private var showingDistanceConfirmation = false
    @State private var pendingPhotosData: [String: [(data: Data, location: CLLocation?, takenAt: Date?)]] = [:]
    @State private var shareToFirestore = true // Firestoreに共有するかどうか（デフォルトON）
    @ObservedObject private var firebaseManager = FirebaseManager.shared
    @ObservedObject private var storageManager = FirebaseStorageManager.shared
    @State private var uploadErrorMessage: String?
    @State private var uploadErrorDetails: [String] = []
    @State private var showMapSelection = false
    @State private var manuallySelectedLocation: CLLocation?
    @State private var hasPhotosWithoutLocation = false

    private let logger = Logger(subsystem: "com.thousandhorse.MatchSpotter", category: "AddPhotoToLocationView")

    var body: some View {
        NavigationView {
            mainContent
                .navigationTitle("写真を追加")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    toolbarContent
                }
                .alert("位置情報の確認", isPresented: $showingDistanceConfirmation) {
                    distanceConfirmationButtons
                } message: {
                    distanceConfirmationMessage
                }
                .alert("アップロードに失敗しました", isPresented: uploadErrorBinding) {
                    Button("OK", role: .cancel) {}
                } message: {
                    uploadErrorMessage_view
                }
                .sheet(isPresented: $showMapSelection) {
                    mapSelectionSheet
                }
                .onChange(of: selectedPhotos) { _, _ in
                    handlePhotosSelectionChange()
                }
        }
    }

    private var mainContent: some View {
        ZStack {
            Form {
                photoSelectionSection
                photoInfoSection
                locationSection
                firestoreSharingSection
                loadingSection
            }

            UploadingOverlayView(
                progress: storageManager.uploadProgress,
                isUploading: isLoadingPhotos || storageManager.isUploading
            )
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("キャンセル") {
                dismiss()
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            Button("追加") {
                Task {
                    await checkPhotosDistance()
                }
            }
            .disabled(selectedPhotos.isEmpty || photoTitle.isEmpty)
        }
    }

    @ViewBuilder
    private var distanceConfirmationButtons: some View {
        Button("はい") {
            Task {
                await savePhotosToSameFolder()
            }
        }
        Button("いいえ", role: .cancel) {
            pendingPhotosData = [:]
        }
    }

    private var distanceConfirmationMessage: some View {
        Text("選択した写真の一部が現在のスポットから100m以上離れています。同じフォルダ内に写真を登録しますか？")
    }

    private var uploadErrorBinding: Binding<Bool> {
        Binding(
            get: { uploadErrorMessage != nil },
            set: { if !$0 { uploadErrorMessage = nil; uploadErrorDetails = [] } }
        )
    }

    private var uploadErrorMessage_view: some View {
        Text(uploadErrorMessage ?? "アップロードに失敗しました。もう一度お試しください。")
    }

    private var mapSelectionSheet: some View {
        MapSelectionView(
            selectedLocation: $manuallySelectedLocation,
            initialLocation: mapInitialLocation
        )
    }

    private var mapInitialLocation: CLLocation? {
        if let manual = manuallySelectedLocation {
            return manual
        } else if let lat = location.latitude, let lon = location.longitude {
            return CLLocation(latitude: lat, longitude: lon)
        }
        return nil
    }

    private func handlePhotosSelectionChange() {
        hasPhotosWithoutLocation = false
        manuallySelectedLocation = nil
    }

    // 写真の距離をチェック
    private func checkPhotosDistance() async {
        guard !selectedPhotos.isEmpty else { return }

        isLoadingPhotos = true

        // 位置情報が異なる写真を別スポットとして分類するためのディクショナリ
        var photosGroupedByLocation: [String: [(data: Data, location: CLLocation?, takenAt: Date?)]] = [:]
        var hasDistantPhotos = false
        var photosWithoutLocationCount = 0

        for item in selectedPhotos {
            // より安全な方法で画像データを取得
            var data: Data?

            // まずData型で直接読み込みを試みる
            if let loadedData = try? await item.loadTransferable(type: Data.self) {
                data = loadedData
            } else {
                // 失敗した場合、UIImageを経由して取得
                if let image = try? await item.loadTransferable(type: Image.self) {
                    let renderer = ImageRenderer(content: image)
                    if let uiImage = renderer.uiImage {
                        data = uiImage.jpegData(compressionQuality: 0.9)
                    }
                }
            }

            guard let imageData = data else { continue }

            let photoLocation = EXIFExtractor.extractLocation(from: imageData)
            let photoTakenAt = EXIFExtractor.extractDate(from: imageData)

            if let takenAt = photoTakenAt {
                logger.debug("📸 写真の撮影日時: \(takenAt.formatted(.dateTime.year().month().day().hour().minute()))")
            } else {
                logger.debug("📸 写真の撮影日時: EXIF情報なし、現在時刻を使用")
            }

            // 位置情報がない写真をカウント
            if photoLocation == nil {
                photosWithoutLocationCount += 1
            }

            // 既存スポットの位置情報
            let existingLocation = location.coordinate

            // 位置情報の距離を計算（100m以上離れていたら別スポット）
            var groupKey = "current" // デフォルトは現在のスポット

            if let photoLoc = photoLocation, let existingLoc = existingLocation {
                let distance = photoLoc.distance(from: CLLocation(latitude: existingLoc.latitude, longitude: existingLoc.longitude))

                // 100m以上離れている場合
                if distance > 100 {
                    groupKey = "\(photoLoc.coordinate.latitude),\(photoLoc.coordinate.longitude)"
                    hasDistantPhotos = true
                }
            } else if let photoLoc = photoLocation {
                // 既存スポットに位置情報がない場合、写真に位置情報があれば別グループ
                groupKey = "\(photoLoc.coordinate.latitude),\(photoLoc.coordinate.longitude)"
            }

            if photosGroupedByLocation[groupKey] == nil {
                photosGroupedByLocation[groupKey] = []
            }
            photosGroupedByLocation[groupKey]?.append((data: imageData, location: photoLocation, takenAt: photoTakenAt))
        }

        isLoadingPhotos = false

        // 位置情報がない写真がある場合、フラグを立てる
        hasPhotosWithoutLocation = photosWithoutLocationCount > 0

        // 100m以上離れた写真がある場合、確認ダイアログを表示
        if hasDistantPhotos {
            pendingPhotosData = photosGroupedByLocation
            showingDistanceConfirmation = true
        } else {
            // 全ての写真が100m以内なら直接保存
            await savePhotos(photosGroupedByLocation, createSeparateLocations: false)
        }
    }

    // 同じフォルダに保存（別スポットとして地図に表示）
    private func savePhotosToSameFolder() async {
        await savePhotos(pendingPhotosData, createSeparateLocations: true)
        pendingPhotosData = [:]
    }

    // 写真を保存
    private func savePhotos(_ photosGroupedByLocation: [String: [(data: Data, location: CLLocation?, takenAt: Date?)]], createSeparateLocations: Bool) async {
        isLoadingPhotos = true
        uploadErrorMessage = nil
        uploadErrorDetails = []
        var createdPhotoData: [PhotoData] = []

        // グループごとに処理
        for (_, photos) in photosGroupedByLocation {
            // 全ての写真を既存のLocationに追加
            // 位置情報が異なる写真も同じスポット内に保存される
            // （例: 新大久保フォルダ内にcafeAとcafeBの写真が両方入る）
            for photoItem in photos {
                // 場所に座標がない場合、写真のEXIF情報から位置情報を取得
                if location.latitude == nil || location.longitude == nil {
                    if let gpsLocation = photoItem.location {
                        location.latitude = gpsLocation.coordinate.latitude
                        location.longitude = gpsLocation.coordinate.longitude
                    }
                }

                // 位置情報の優先順位: 1. EXIF情報 2. 手動選択
                let finalPhotoLocation = photoItem.location ?? manuallySelectedLocation
                let photoLatitude = finalPhotoLocation?.coordinate.latitude
                let photoLongitude = finalPhotoLocation?.coordinate.longitude

                // 写真データを作成（写真独自の位置情報を保存）
                let photoData = PhotoData(
                    imageData: photoItem.data,
                    title: photoTitle,
                    caption: photoCaption.isEmpty ? nil : photoCaption,
                    takenAt: photoItem.takenAt ?? Date(), // EXIFから取得した撮影日時、なければ現在時刻
                    latitude: photoLatitude,
                    longitude: photoLongitude
                )
                photoData.location = location
                location.photos.append(photoData)
                modelContext.insert(photoData)
                createdPhotoData.append(photoData)

                // Firestoreに共有する場合（メインスレッドで実行）
                if shareToFirestore, let userId = firebaseManager.currentUser?.id {
                    do {
                        let uploadedPhoto = try await storageManager.uploadPhoto(
                            imageData: photoItem.data,
                            title: photoTitle,
                            caption: photoCaption.isEmpty ? nil : photoCaption,
                            latitude: photoLatitude,
                            longitude: photoLongitude,
                            locationName: location.name,
                            prefectureName: location.prefecture?.name,
                            userId: userId,
                            userName: firebaseManager.currentUser?.displayName,
                            takenAt: photoItem.takenAt ?? Date() // EXIFから取得した撮影日時、なければ現在時刻
                        )

                        // FirestoreのドキュメントIDをローカルPhotoDataに保存
                        photoData.firestoreId = uploadedPhoto.id
                    } catch {
                        logger.error("Firestoreへのアップロードエラー: \(error.localizedDescription)")
                        uploadErrorDetails.append(error.localizedDescription)
                        // アップロードに失敗した場合、コンテキストからPhotoDataを削除してロールバックします
                        location.photos.removeAll { $0 === photoData }
                        modelContext.delete(photoData)
                    }
                }
            }
        }

        if !uploadErrorDetails.isEmpty {
            uploadErrorMessage = uploadErrorDetails.joined(separator: "\n")
            for photo in createdPhotoData {
                location.photos.removeAll { $0 === photo }
                modelContext.delete(photo)
            }
            isLoadingPhotos = false
            return
        }

        // 保存
        do {
            try modelContext.save()
            dismiss()
        } catch {
            logger.error("写真の保存エラー: \(error.localizedDescription)")
            uploadErrorMessage = "ローカルデータベースへの保存に失敗しました。アップロードが成功している可能性があります。"
            for photo in createdPhotoData {
                if let firestoreId = photo.firestoreId {
                    Task {
                        await FirebaseStorageManager.shared.deleteOrphanedPhoto(firestoreId: firestoreId)
                    }
                }
            }
            for photo in createdPhotoData {
                location.photos.removeAll { $0 === photo }
                modelContext.delete(photo)
            }
        }

        isLoadingPhotos = false
    }

    // 位置情報から住所を取得
    private func getAddress(from location: CLLocation) async -> String {
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
                    return name
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

                let address = components.joined(separator: " ")
                return address.isEmpty ? "不明なスポット" : address
            }
        } catch {
            logger.error("住所取得エラー: \(error.localizedDescription)")
        }
        return "不明なスポット"
    }

    // MARK: - View Sections

    @ViewBuilder
    private var photoSelectionSection: some View {
        Section("写真を選択") {
            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 10,
                matching: .images,
                photoLibrary: .shared()
            ) {
                photoPickerLabel
            }

            if !selectedPhotos.isEmpty {
                Text("✓ \(selectedPhotos.count)枚の写真が選択されています")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }

    @ViewBuilder
    private var photoPickerLabel: some View {
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

    @ViewBuilder
    private var photoInfoSection: some View {
        Section {
            TextField("タイトル（必須）", text: $photoTitle)
            TextField("詳細（任意）", text: $photoCaption, axis: .vertical)
                .lineLimit(3...6)

            if selectedPhotos.count > 1 {
                Text("ℹ️ このタイトルと詳細は、選択した全ての写真に適用されます")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("写真情報")
        }
    }

    @ViewBuilder
    private var locationSection: some View {
        if !selectedPhotos.isEmpty {
            Section {
                Button {
                    showMapSelection = true
                } label: {
                    HStack {
                        Image(systemName: "map")
                            .foregroundColor(.pink)
                        Text(manuallySelectedLocation != nil ? "位置を調整" : "地図で位置を選択")
                            .foregroundColor(.pink)
                        Spacer()
                        if manuallySelectedLocation != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                locationHintText
            } header: {
                Text("位置情報")
            }
        }
    }

    @ViewBuilder
    private var locationHintText: some View {
        if hasPhotosWithoutLocation && manuallySelectedLocation == nil {
            Text("選択した写真に位置情報が含まれていません。地図から手動で選択できます。")
                .font(.caption)
                .foregroundColor(.secondary)
        } else if manuallySelectedLocation != nil {
            Text("✓ 位置情報が設定されました（位置情報がない写真に適用されます）")
                .font(.caption)
                .foregroundColor(.green)
        } else {
            Text("写真の位置情報を調整できます")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var firestoreSharingSection: some View {
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
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("写真を追加中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

#Preview {
    let location = Location(name: "新宿")
    return AddPhotoToLocationView(location: location)
        .modelContainer(for: [Prefecture.self, Location.self, PhotoData.self], inMemory: true)
}
