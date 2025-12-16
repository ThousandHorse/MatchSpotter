//
//  SharedPhotosView.swift
//  MatchSpotter
//
//  Created by Claude
//

import SwiftUI
import FirebaseFirestore
import OSLog

/// 共有写真一覧画面
struct SharedPhotosListView: View {
    @ObservedObject private var firebaseManager = FirebaseManager.shared
    @State private var selectedFilter: PhotoFilter = .all
    @State private var fetchError: String?
    @State private var showFetchError = false

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    private let logger = Logger(subsystem: "com.thousandhorse.MatchSpotter", category: "SharedPhotosListView")

    var body: some View {
        VStack(spacing: 0) {
            // フィルタ選択
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    FilterButton(title: "全て", isSelected: selectedFilter == .all) {
                        selectedFilter = .all
                        Task {
                            await fetchPhotosWithErrorHandling(filter: .all)
                        }
                    }

                    FilterButton(title: "マイ写真", isSelected: selectedFilter == .myPhotos) {
                        selectedFilter = .myPhotos
                        Task {
                            await fetchPhotosWithErrorHandling(filter: .myPhotos)
                        }
                    }

                    FilterButton(title: "最近", isSelected: selectedFilter == .recent) {
                        selectedFilter = .recent
                        Task {
                            await fetchPhotosWithErrorHandling(filter: .recent)
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemBackground))

            Divider()

            // 写真グリッド
            if firebaseManager.isLoading {
                ProgressView("読み込み中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = firebaseManager.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    Text("エラーが発生しました")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("再読み込み") {
                        Task {
                            await fetchPhotosWithErrorHandling(filter: selectedFilter)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if firebaseManager.sharedPhotos.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("まだ写真がありません")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("リストから写真を公開して共有しましょう")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(firebaseManager.sharedPhotos) { photo in
                            NavigationLink {
                                SharedPhotoDetailView(photo: photo)
                            } label: {
                                SharedPhotoGridItem(photo: photo)
                            }
                            .onAppear {
                                // 最後のアイテムに到達したら次のページを読み込む
                                if photo.id == firebaseManager.sharedPhotos.last?.id {
                                    loadMorePhotosIfNeeded()
                                }
                            }
                        }

                        // 次のページがある場合、ローディングインジケータを表示
                        if firebaseManager.hasMorePhotos {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding()
                                Spacer()
                            }
                            .gridCellColumns(3) // 3列分のスペースを使用
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
        }
        .navigationTitle("共有写真")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchPhotosWithErrorHandling(filter: selectedFilter)
        }
        .alert("写真取得エラー", isPresented: $showFetchError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(fetchError ?? "写真の取得に失敗しました")
        }
    }

    /// エラーハンドリング付きで写真を取得
    private func fetchPhotosWithErrorHandling(filter: PhotoFilter) async {
        do {
            try await firebaseManager.fetchPhotos(filter: filter)
            logger.info("✅ 写真取得成功")
        } catch {
            logger.error("❌ 写真取得失敗: \(error.localizedDescription)")
            fetchError = error.localizedDescription
            showFetchError = true
        }
    }

    /// 次のページを読み込む（必要な場合のみ）
    private func loadMorePhotosIfNeeded() {
        guard firebaseManager.hasMorePhotos, !firebaseManager.isLoading else {
            return
        }

        Task {
            do {
                try await firebaseManager.fetchMorePhotos()
                logger.info("✅ 次のページ読み込み成功")
            } catch {
                logger.error("❌ 次のページ読み込み失敗: \(error.localizedDescription)")
                fetchError = error.localizedDescription
                showFetchError = true
            }
        }
    }
}

/// フィルタボタン
struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.pink : Color.secondary.opacity(0.1))
                .cornerRadius(20)
        }
    }
}

/// 写真グリッドアイテム
struct SharedPhotoGridItem: View {
    let photo: SharedPhoto

    var body: some View {
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
}

/// 共有写真詳細画面
struct SharedPhotoDetailView: View {
    let photo: SharedPhoto
    @ObservedObject private var firebaseManager = FirebaseManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var deleteError: String?
    @State private var showDeleteError = false
    @State private var likeError: String?
    @State private var showLikeError = false

    private let logger = Logger(subsystem: "com.thousandhorse.MatchSpotter", category: "SharedPhotoDetailView")

    var body: some View {
        NavigationStack {
            ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 画像
                AsyncImage(url: URL(string: photo.imageURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)

                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .aspectRatio(16/9, contentMode: .fit)
                            .overlay {
                                ProgressView()
                            }

                    case .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .aspectRatio(16/9, contentMode: .fit)
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                            }

                    @unknown default:
                        EmptyView()
                    }
                }

                // 情報セクション
                VStack(alignment: .leading, spacing: 12) {
                    // タイトル
                    Text(photo.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    // ユーザー情報
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.secondary)
                        Text(photo.userName ?? "匿名ユーザー")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // いいねボタン
                    HStack {
                        Button {
                            Task {
                                await toggleLikeWithErrorHandling()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: photo.likedBy.contains(firebaseManager.currentUser?.id ?? "") ? "heart.fill" : "heart")
                                    .foregroundColor(photo.likedBy.contains(firebaseManager.currentUser?.id ?? "") ? .red : .secondary)
                                Text("\(photo.likes)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    // キャプション
                    if let caption = photo.caption {
                        Text(caption)
                            .font(.body)
                    }

                    // 場所情報
                    if let locationName = photo.locationName {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.pink)
                            Text(locationName)
                                .font(.subheadline)
                        }
                    }

                    if let prefectureName = photo.prefectureName {
                        HStack {
                            Image(systemName: "map.fill")
                                .foregroundColor(.blue)
                            Text(prefectureName)
                                .font(.subheadline)
                        }
                    }

                    // 撮影日時
                    Text("撮影日: \(photo.takenAt.formatted(.dateTime.year().month().day().locale(Locale(identifier: "ja_JP"))))")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // 投稿日時
                    Text("投稿日: \(photo.uploadedAt.formatted(.dateTime.year().month().day().locale(Locale(identifier: "ja_JP"))))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            // 自分がアップロードした写真の場合のみ削除ボタンを表示
            if let currentUserId = firebaseManager.currentUser?.id,
               photo.userId == currentUserId {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .confirmationDialog("この写真を削除しますか？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("削除", role: .destructive) {
                Task {
                    await deletePhotoWithErrorHandling()
                }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .alert("削除エラー", isPresented: $showDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "写真の削除に失敗しました")
        }
        .alert("いいねエラー", isPresented: $showLikeError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(likeError ?? "いいねの更新に失敗しました")
        }
        }
    }

    /// エラーハンドリング付きで写真を削除
    private func deletePhotoWithErrorHandling() async {
        do {
            try await firebaseManager.deletePhoto(photo: photo)
            logger.info("✅ 写真削除成功、画面を閉じます")
            dismiss()
        } catch {
            logger.error("❌ 写真削除失敗: \(error.localizedDescription)")
            deleteError = error.localizedDescription
            showDeleteError = true
            // 画面は閉じない
        }
    }

    /// エラーハンドリング付きでいいねを切り替え
    private func toggleLikeWithErrorHandling() async {
        do {
            try await firebaseManager.toggleLike(photo: photo)
            logger.info("✅ いいね更新成功")
        } catch {
            logger.error("❌ いいね更新失敗: \(error.localizedDescription)")
            likeError = error.localizedDescription
            showLikeError = true
        }
    }
}

#Preview {
    NavigationStack {
        SharedPhotosListView()
    }
}
