//
//  UnifiedPhotoListView.swift
//  MatchSpotter
//
//  統合された写真一覧表示ビュー（ローカル + Firestore）
//

import SwiftUI
import SwiftData
import OSLog
import FirebaseFirestore

/// 統合された写真リスト表示ビュー（第3階層）
struct UnifiedPhotoListView: View {
    let unifiedLocation: UnifiedLocation
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var firebaseManager = FirebaseManager.shared
    @State private var showEditView = false
    @State private var showDeleteConfirmation = false
    @State private var unifiedPhotos: [UnifiedPhoto] = []
    @State private var placeGroups: [PlaceGroup] = [] // お店名でグループ化
    @State private var isLoading = false
    @State private var sharedPhotos: [SharedPhoto] = []
    @State private var lastLocationDocument: DocumentSnapshot?
    @State private var hasMoreSharedPhotos = false
    @State private var isLoadingMore = false
    @State private var loadErrorMessage: String?
    @State private var locationForAddPhoto: Location?
    @Query private var allPrefectures: [Prefecture]
    private let duplicateToleranceSeconds: TimeInterval = 10 // 10秒以内なら同じ写真とみなす

    private let logger = Logger(subsystem: "com.thousandhorse.MatchSpotter", category: "UnifiedPhotoListView")

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    if placeGroups.isEmpty && !isLoading {
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
                        ForEach(placeGroups, id: \.id) { placeGroup in
                            NavigationLink(destination: PlacePhotosGridView(placeGroup: placeGroup, unifiedLocation: unifiedLocation)) {
                                PlaceFolderRowView(placeGroup: placeGroup)
                            }

                            if placeGroup.id != placeGroups.last?.id {
                                Divider()
                                    .padding(.leading, 96)
                            }
                        }

                        if hasMoreSharedPhotos {
                            HStack {
                                Spacer()
                                Button {
                                    Task {
                                        await loadUnifiedPhotos(loadMore: true)
                                    }
                                } label: {
                                    if isLoadingMore {
                                        ProgressView()
                                    } else {
                                        Text("もっと見る")
                                            .font(.callout)
                                            .foregroundColor(.pink)
                                    }
                                }
                                .disabled(isLoadingMore)
                                Spacer()
                            }
                            .padding(.vertical, 12)
                        }
                    }
                }
            }

            if isLoading {
                ProgressView("データを同期中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground).opacity(0.8))
            }
        }
        .navigationTitle(unifiedLocation.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // 写真追加ボタン（常に表示）
                    Button {
                        Task {
                            await handleAddPhotoButtonTap()
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.pink)
                    }

                    // メニュー（ローカルの場所がある場合のみ）
                    if unifiedLocation.localLocation != nil {
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
        }
        .sheet(isPresented: $showEditView) {
            if let localLocation = unifiedLocation.localLocation {
                EditLocationView(location: localLocation)
            }
        }
        .sheet(item: $locationForAddPhoto, onDismiss: {
            Task {
                await loadUnifiedPhotos()
            }
        }) { location in
            AddPhotoToLocationView(location: location)
        }
        .confirmationDialog(
            "本当にこの場所を削除しますか？",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                deleteLocalLocation()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この操作は取り消せません。場所に紐づくローカル写真もすべて削除されます。（共有写真は削除されません）")
        }
        .task {
            await loadUnifiedPhotos()
        }
        .refreshable {
            await loadUnifiedPhotos()
        }
        .alert("読み込みに失敗しました", isPresented: Binding(
            get: { loadErrorMessage != nil },
            set: { if !$0 { loadErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(loadErrorMessage ?? "読み込みに失敗しました。")
        }
    }

    private func loadUnifiedPhotos(loadMore: Bool = false) async {
        if loadMore {
            guard hasMoreSharedPhotos, !isLoadingMore else { return }
            isLoadingMore = true
        } else {
            isLoading = true
            lastLocationDocument = nil
        }

        do {
            let page = try await firebaseManager.fetchPhotosForLocation(
                prefectureName: unifiedLocation.prefectureName,
                locationName: unifiedLocation.name,
                lastDocument: loadMore ? lastLocationDocument : nil
            )

            if loadMore {
                sharedPhotos.append(contentsOf: page.photos)
            } else {
                sharedPhotos = page.photos
            }
            lastLocationDocument = page.lastDocument
            hasMoreSharedPhotos = page.hasMore

            let unified = buildUnifiedPhotos(sharedPhotos: sharedPhotos)
            self.unifiedPhotos = unified
            self.placeGroups = groupPhotosByPlace(photos: unified)
            logger.info("📊 統合写真数: \(unified.count)件（ローカル: \(unified.filter { $0.isLocal }.count)件、共有: \(unified.filter { !$0.isLocal }.count)件）")
            logger.info("📁 お店グループ数: \(placeGroups.count)件")

            if loadMore {
                isLoadingMore = false
            } else {
                isLoading = false
            }
        } catch {
            logger.error("統合写真読み込みエラー: \(error.localizedDescription)")
            loadErrorMessage = error.localizedDescription
            hasMoreSharedPhotos = false
            if loadMore {
                isLoadingMore = false
            } else {
                isLoading = false
            }
        }
    }

    private func buildUnifiedPhotos(sharedPhotos: [SharedPhoto]) -> [UnifiedPhoto] {
        var unified: [UnifiedPhoto] = []

        // 現在のユーザーID
        let currentUserId = firebaseManager.currentUser?.id

        // ローカルの写真を追加（Firestoreに存在しないもののみ）
        if let localLocation = unifiedLocation.localLocation {
            for localPhoto in localLocation.photos {
                // このローカル写真がFirestoreにアップロード済みかチェック
                let isDuplicate: Bool

                if let firestoreId = localPhoto.firestoreId, !firestoreId.isEmpty {
                    // firestoreIdがある場合は、IDの有無で正確に判定
                    isDuplicate = sharedPhotos.contains { $0.id == firestoreId }
                } else {
                    // firestoreIdがない場合は、従来のタイトル+日時での判定にフォールバック
                    isDuplicate = sharedPhotos.contains { sharedPhoto in
                        guard sharedPhoto.userId == currentUserId else { return false }
                        let titleMatches = sharedPhoto.title == (localPhoto.title ?? "")
                        let dateDifference = abs(sharedPhoto.takenAt.timeIntervalSince(localPhoto.takenAt))
                        let dateMatches = dateDifference < duplicateToleranceSeconds
                        return titleMatches && dateMatches
                    }
                }

                // 重複していなければローカル写真を追加
                if !isDuplicate {
                    unified.append(.local(localPhoto))
                } else {
                    logger.debug("🔄 重複除外: ローカル写真「\(localPhoto.title ?? "無題")」は既に共有済み")
                }
            }
        }

        // Firestoreの写真を追加
        for sharedPhoto in sharedPhotos {
            unified.append(.shared(sharedPhoto))
        }

        // 撮影日時の降順でソート
        return unified.sorted { $0.takenAt > $1.takenAt }
    }

    /// 写真をお店名（title）でグループ化
    private func groupPhotosByPlace(photos: [UnifiedPhoto]) -> [PlaceGroup] {
        var groups: [String: [UnifiedPhoto]] = [:]

        for photo in photos {
            let placeName = photo.title ?? "タイトルなし"
            if groups[placeName] == nil {
                groups[placeName] = []
            }
            groups[placeName]?.append(photo)
        }

        // PlaceGroupに変換して、最新の撮影日時順にソート
        return groups.map { PlaceGroup(placeName: $0.key, photos: $0.value) }
            .sorted { $0.latestTakenAt > $1.latestTakenAt }
    }

    // 場所を削除（ローカルのみ）
    private func deleteLocalLocation() {
        if let localLocation = unifiedLocation.localLocation {
            modelContext.delete(localLocation)
            dismiss()
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
            logger.error("❌ Location作成失敗")
        }
    }
}

/// お店名フォルダの行ビュー
struct PlaceFolderRowView: View {
    let placeGroup: PlaceGroup

    var body: some View {
        HStack(spacing: 16) {
            // フォルダアイコン
            Image(systemName: "folder.fill")
                .font(.system(size: 40))
                .foregroundColor(.pink)
                .frame(width: 60, height: 60)

            // 右側の情報
            VStack(alignment: .leading, spacing: 6) {
                // お店名
                Text(placeGroup.placeName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }

            Spacer()

            // 右矢印
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
    }
}

/// グリッドアイテムビュー（iOS写真アプリスタイル）
struct UnifiedPhotoGridItemView: View {
    let photo: UnifiedPhoto
    let localPhotos: [PhotoData]
    @State private var showingFullScreen = false
    @State private var loadedImage: UIImage?

    private let firebaseManager = FirebaseManager.shared

    var body: some View {
        Button {
            showingFullScreen = true
        } label: {
            GeometryReader { geometry in
                ZStack(alignment: .bottomTrailing) {
                    // 画像表示
                    if let image = loadedImage {
                        // ローカルから読み込めた場合（local写真 or ローカルに存在する自分の共有写真）
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.width)
                            .clipped()
                    } else if case .shared(let sharedPhoto) = photo {
                        // 共有写真でローカルに存在しない場合はAsyncImageで読み込む
                        AsyncImage(url: URL(string: sharedPhoto.imageURL)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geometry.size.width, height: geometry.size.width)
                                    .clipped()
                            case .empty:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay {
                                        ProgressView()
                                    }
                            case .failure:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay {
                                        Image(systemName: "photo")
                                            .font(.title)
                                            .foregroundColor(.gray)
                                    }
                            @unknown default:
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                            }
                        }
                    } else {
                        // ローカル写真だがまだ読み込まれていない場合
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.title)
                                    .foregroundColor(.gray)
                            }
                    }

                    // ソース表示（ローカル/共有）
                    if !photo.isLocal {
                        HStack(spacing: 4) {
                            Image(systemName: "cloud.fill")
                                .font(.system(size: 10))
                            Text("共有")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(4)
                        .padding(4)
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingFullScreen) {
            switch photo {
            case .local(let photoData):
                PhotoDetailView(photo: photoData)

            case .shared(let sharedPhoto):
                SharedPhotoDetailView(photo: sharedPhoto)
            }
        }
        .task {
            await loadImage()
        }
    }

    private func loadImage() async {
        switch photo {
        case .local(let photoData):
            if let image = UIImage(data: photoData.imageData) {
                loadedImage = image
            }

        case .shared(let sharedPhoto):
            // 自分がアップロードした共有写真で、ローカルにも存在する場合はローカルから読み込む
            if sharedPhoto.userId == firebaseManager.currentUser?.id,
               let firestoreId = sharedPhoto.id,
               let localPhoto = localPhotos.first(where: { $0.firestoreId == firestoreId }) {
                if let image = UIImage(data: localPhoto.imageData) {
                    loadedImage = image
                }
            }
            // それ以外はAsyncImageを使用（bodyで処理）
        }
    }
}

#Preview {
    let location = Location(name: "新宿")
    let unifiedLocation = UnifiedLocation(
        name: "新宿",
        prefectureName: "東京都",
        localLocation: location,
        photoCount: 10
    )
    return NavigationStack {
        UnifiedPhotoListView(unifiedLocation: unifiedLocation)
    }
    .modelContainer(for: [Prefecture.self, Location.self, PhotoData.self], inMemory: true)
}
