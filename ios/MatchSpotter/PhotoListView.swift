//
//  PhotoListView.swift
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

private let logger = Logger(subsystem: "com.thousandhorse.MatchSpotter", category: "PhotoDetailView")

/// 写真リスト表示ビュー（第3階層）
struct PhotoListView: View {
    let location: Location
    var filteredPhotoId: String? = nil // 特定の写真のみ表示する場合のID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var showEditView = false
    @State private var showDeleteConfirmation = false
    @State private var showAddPhoto = false
    
    // 表示する写真リスト（フィルタリング適用）
    private var displayPhotos: [PhotoData] {
        if let photoId = filteredPhotoId {
            return location.photos.filter { $0.persistentModelID.hashValue.description == photoId }
        }
        return location.photos
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if displayPhotos.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("まだ写真がありません")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    ForEach(displayPhotos, id: \.id) { photo in
                        PhotoListRowView(photo: photo)
                        if photo.id != displayPhotos.last?.id {
                            Divider()
                                .padding(.leading, 96)
                        }
                    }
                }
            }
        }
        .navigationTitle(location.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // 写真追加ボタン
                    Button {
                        showAddPhoto = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.pink)
                    }
                    
                    // メニュー
                    Menu {
                        Button {
                            showEditView = true
                        } label: {
                            Label("編集", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showEditView) {
            EditLocationView(location: location)
        }
        .sheet(isPresented: $showAddPhoto) {
            AddPhotoToLocationView(location: location)
        }
        .confirmationDialog(
            "本当にこの場所を削除しますか？",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                deleteLocation()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この操作は取り消せません。場所に紐づく写真もすべて削除されます。")
        }
    }
    
    // 場所を削除
    private func deleteLocation() {
        modelContext.delete(location)
        dismiss()
    }
}

/// 写真リスト行ビュー - リスト内の各写真を表示
struct PhotoListRowView: View {
    let photo: PhotoData
    @State private var showingFullScreen = false
    
    var body: some View {
        Button {
            showingFullScreen = true
        } label: {
            HStack(spacing: 16) {
                // サムネイル画像
                if let uiImage = UIImage(data: photo.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundStyle(.gray)
                        }
                }
                
                // 右側の情報
                VStack(alignment: .leading, spacing: 6) {
                    // タイトル
                    if let title = photo.title {
                        Text(title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    } else {
                        Text("タイトルなし")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    // 詳細（任意）
                    if let caption = photo.caption {
                        Text(caption)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    // 撮影日時
                    Text(photo.takenAt.formatted(.dateTime.year().month().day().locale(Locale(identifier: "ja_JP"))))
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // 右矢印
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingFullScreen) {
            PhotoDetailView(photo: photo)
        }
    }
}

/// 写真詳細ビュー - フルスクリーンで写真とキャプションを表示
struct PhotoDetailView: View {
    let photo: PhotoData
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var firebaseManager = FirebaseManager.shared
    @ObservedObject private var storageManager = FirebaseStorageManager.shared
    
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingLocationPicker = false
    @State private var showingUploadConfirmation = false
    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var uploadSuccess = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let uiImage = UIImage(data: photo.imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .clipped()
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 100))
                            .foregroundColor(.secondary)
                    }
                    
                    if let title = photo.title {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("お店、スポット名")
                                .font(.headline)
                            Text(title)
                                .font(.body)
                        }
                        .padding(.horizontal)
                    }
                    
                    if let caption = photo.caption {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("詳細")
                                .font(.headline)
                            Text(caption)
                                .font(.body)
                        }
                        .padding(.horizontal)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("撮影日時")
                            .font(.headline)
                        Text(photo.takenAt.formatted(.dateTime.year().month().day().locale(Locale(identifier: "ja_JP"))))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // 位置情報セクション
                    VStack(alignment: .leading, spacing: 8) {
                        Text("位置情報")
                            .font(.headline)
                        
                        if let lat = photo.latitude, let lon = photo.longitude {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("緯度: \(lat, specifier: "%.6f")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("経度: \(lon, specifier: "%.6f")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Button {
                                showingLocationPicker = true
                            } label: {
                                Label("位置を編集", systemImage: "mappin.and.ellipse")
                                    .font(.callout)
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Text("位置情報なし")
                                .font(.body)
                                .foregroundColor(.secondary)
                            
                            Button {
                                showingLocationPicker = true
                            } label: {
                                Label("位置を設定", systemImage: "mappin.and.ellipse")
                                    .font(.callout)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 写真公開セクション
                    VStack(alignment: .leading, spacing: 12) {
                        Text("共有")
                            .font(.headline)
                        
                        if isUploading {
                            VStack(spacing: 8) {
                                ProgressView(value: storageManager.uploadProgress)
                                    .progressViewStyle(.linear)
                                Text("公開中... \(Int(storageManager.uploadProgress * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else if uploadSuccess {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("公開済み")
                                    .font(.body)
                                    .foregroundColor(.green)
                            }
                        } else {
                            Button {
                                showingUploadConfirmation = true
                            } label: {
                                Label("全員に公開", systemImage: "cloud.fill")
                                    .font(.callout)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.pink)
                        }
                        
                        if let error = uploadError {
                            Text("エラー: \(error)")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            showingEditSheet = true
                        } label: {
                            Image(systemName: "pencil.circle")
                                .font(.title3)
                        }
                        
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash.circle")
                                .font(.title3)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                EditPhotoView(photo: photo)
            }
            .sheet(isPresented: $showingLocationPicker) {
                MapLocationPickerView(selectedLatitude: Binding(
                    get: { photo.latitude },
                    set: { newValue in
                        photo.latitude = newValue
                        try? modelContext.save()
                    }
                ), selectedLongitude: Binding(
                    get: { photo.longitude },
                    set: { newValue in
                        photo.longitude = newValue
                        try? modelContext.save()
                    }
                ))
            }
            .confirmationDialog(
                "この写真を削除しますか？",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("削除", role: .destructive) {
                    deletePhoto()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("この操作は取り消せません。")
            }
            .confirmationDialog(
                "この写真を公開しますか？",
                isPresented: $showingUploadConfirmation,
                titleVisibility: .visible
            ) {
                Button("公開する") {
                    Task {
                        await uploadToFirebase()
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("他のユーザーがこの写真を閲覧できるようになります。")
            }
        }
    }
    
    private func deletePhoto() {
        modelContext.delete(photo)
        dismiss()
    }
    
    private func uploadToFirebase() async {
        guard let userId = firebaseManager.currentUser?.id else {
            uploadError = "ログインが必要です"
            return
        }
        
        isUploading = true
        uploadError = nil
        
        
        do {
            let uploadedPhoto = try await storageManager.uploadPhoto(
                imageData: photo.imageData,
                title: photo.title ?? "無題",
                caption: photo.caption,
                latitude: photo.latitude,
                longitude: photo.longitude,
                locationName: photo.location?.name,
                prefectureName: photo.location?.prefecture?.name,
                userId: userId,
                userName: firebaseManager.currentUser?.displayName,
                takenAt: photo.takenAt
            )
            
            // FirestoreのドキュメントIDをローカルPhotoDataに保存
            photo.firestoreId = uploadedPhoto.id
            do {
                try modelContext.save()
            } catch {
                logger.error("❌ ローカルDBへのFirestoreID保存失敗: \(error.localizedDescription)")
                uploadError = "写真の公開には成功しましたが、ローカルDBの更新に失敗しました。アプリを再起動してデータをご確認ください。"
            }
            
            
            isUploading = false
            uploadSuccess = true
        } catch {
            isUploading = false
            uploadError = error.localizedDescription
        }
    }
}

/// 写真編集ビュー - タイトルとキャプションを編集、写真を追加
struct EditPhotoView: View {
    let photo: PhotoData
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var editedTitle: String
    @State private var editedCaption: String
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isLoadingPhotos = false
    @State private var showingAddPhotoSuccess = false
    
    private let logger = Logger(subsystem: "com.thousandhorse.MatchSpotter", category: "EditPhotoView")
    
    init(photo: PhotoData) {
        self.photo = photo
        _editedTitle = State(initialValue: photo.title ?? "")
        _editedCaption = State(initialValue: photo.caption ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("写真情報") {
                    TextField("タイトル（必須）", text: $editedTitle)
                    TextField("詳細（任意）", text: $editedCaption, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                // 登録済み写真の一覧
                if let location = photo.location, !location.photos.isEmpty {
                    Section("登録済みの写真（\(location.photos.count)枚）") {
                        ForEach(location.photos) { photoItem in
                            HStack(spacing: 12) {
                                // サムネイル
                                if let uiImage = UIImage(data: photoItem.imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 60, height: 60)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(photoItem.title ?? "タイトルなし")
                                        .font(.system(size: 14, weight: .medium))
                                    Text(photoItem.takenAt.formatted(.dateTime.year().month().day().locale(Locale(identifier: "ja_JP"))))
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                            }
                        }
                        .onDelete(perform: deletePhotos)
                    }
                }
                
                Section("写真を追加") {
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
            .navigationTitle("写真を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task {
                            await saveChanges()
                        }
                    }
                    .disabled(editedTitle.isEmpty)
                }
            }
            .alert("写真を追加しました", isPresented: $showingAddPhotoSuccess) {
                Button("OK") {
                    showingAddPhotoSuccess = false
                }
            }
        }
    }
    
    private func saveChanges() async {
        // タイトルとキャプションを保存
        photo.title = editedTitle
        photo.caption = editedCaption.isEmpty ? nil : editedCaption
        
        // 選択された写真を追加
        if !selectedPhotos.isEmpty, let location = photo.location {
            isLoadingPhotos = true
            
            for item in selectedPhotos {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let gpsLocation = extractLocationFromPhoto(data)
                    
                    // 位置情報の更新（最初の写真から取得）
                    if location.latitude == nil || location.longitude == nil {
                        if let gpsLoc = gpsLocation {
                            location.latitude = gpsLoc.coordinate.latitude
                            location.longitude = gpsLoc.coordinate.longitude
                        }
                    }
                    
                    let photoData = PhotoData(
                        imageData: data,
                        title: editedTitle,
                        caption: editedCaption.isEmpty ? nil : editedCaption,
                        latitude: gpsLocation?.coordinate.latitude,
                        longitude: gpsLocation?.coordinate.longitude
                    )
                    photoData.location = location
                    location.photos.append(photoData)
                    modelContext.insert(photoData)
                }
            }
            
            isLoadingPhotos = false
            showingAddPhotoSuccess = true
            selectedPhotos = []
        }
        
        // 保存
        do {
            try modelContext.save()
            if selectedPhotos.isEmpty {
                dismiss()
            }
        } catch {
            logger.error("保存エラー: \(error.localizedDescription)")
        }
    }
    
    // 登録済み写真を削除
    private func deletePhotos(offsets: IndexSet) {
        guard let location = photo.location else { return }
        
        for index in offsets {
            let photoToDelete = location.photos[index]
            modelContext.delete(photoToDelete)
        }
        
        do {
            try modelContext.save()
        } catch {
            logger.error("削除エラー: \(error.localizedDescription)")
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
}

#Preview {
    let location = Location(name: "新宿", latitude: 35.6895, longitude: 139.7006)
    return PhotoListView(location: location)
        .modelContainer(for: [Prefecture.self, Location.self, PhotoData.self], inMemory: true)
}
