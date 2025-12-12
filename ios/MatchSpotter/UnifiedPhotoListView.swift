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
    @StateObject private var firebaseManager = FirebaseManager.shared
    @State private var showEditView = false
    @State private var showDeleteConfirmation = false
    @State private var showAddPhoto = false
    @State private var unifiedPhotos: [UnifiedPhoto] = []
    @State private var isLoading = false
    @State private var sharedPhotos: [SharedPhoto] = []
    @State private var lastLocationDocument: DocumentSnapshot?
    @State private var hasMoreSharedPhotos = false
    @State private var isLoadingMore = false
    @State private var loadErrorMessage: String?
    private let duplicateToleranceSeconds: TimeInterval = 10 // 10秒以内なら同じ写真とみなす

    private let logger = Logger(subsystem: "com.thousandhorse.MatchSpotter", category: "UnifiedPhotoListView")

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if unifiedPhotos.isEmpty && !isLoading {
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
                        ForEach(unifiedPhotos, id: \.id) { photo in
                            UnifiedPhotoListRowView(
                                photo: photo,
                                localPhotos: unifiedLocation.localLocation?.photos ?? []
                            )
                            if photo.id != unifiedPhotos.last?.id {
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
                    // 写真追加ボタン（ローカルの場所がある場合のみ）
                    if unifiedLocation.localLocation != nil {
                        Button {
                            showAddPhoto = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.pink)
                        }
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
        .sheet(isPresented: $showAddPhoto) {
            if let localLocation = unifiedLocation.localLocation {
                AddPhotoToLocationView(location: localLocation)
            }
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
            logger.info("📊 統合写真数: \(unified.count)件（ローカル: \(unified.filter { $0.isLocal }.count)件、共有: \(unified.filter { !$0.isLocal }.count)件）")

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

    // 場所を削除（ローカルのみ）
    private func deleteLocalLocation() {
        if let localLocation = unifiedLocation.localLocation {
            modelContext.delete(localLocation)
            dismiss()
        }
    }
}

/// 統合された写真リスト行ビュー
struct UnifiedPhotoListRowView: View {
    let photo: UnifiedPhoto
    let localPhotos: [PhotoData]
    @StateObject private var firebaseManager = FirebaseManager.shared
    @State private var showingFullScreen = false
    @State private var thumbnailImage: UIImage?

    var body: some View {
        Button {
            showingFullScreen = true
        } label: {
            HStack(spacing: 16) {
                // サムネイル画像（最適化版）
                if let thumbnailImage = thumbnailImage {
                    Image(uiImage: thumbnailImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    placeholderView
                        .task {
                            await loadThumbnail()
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

                    // ソース表示
                    HStack(spacing: 8) {
                        // 詳細（任意）
                        if let caption = photo.caption {
                            Text(caption)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        if !photo.isLocal {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("共有")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
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
            switch photo {
            case .local(let photoData):
                PhotoDetailView(photo: photoData)

            case .shared(let sharedPhoto):
                SharedPhotoDetailView(photo: sharedPhoto)
            }
        }
    }

    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.2))
            .frame(width: 80, height: 80)
            .overlay {
                Image(systemName: "photo")
                    .font(.title2)
                    .foregroundStyle(.gray)
            }
    }

    /// サムネイル画像を最適化して読み込み（自分の写真はローカル版を使用）
    private func loadThumbnail() async {
        if let imageData = await photo.getImageData(
            currentUserId: firebaseManager.currentUser?.id,
            localPhotos: localPhotos
        ), let image = UIImage(data: imageData) {
            thumbnailImage = image
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
