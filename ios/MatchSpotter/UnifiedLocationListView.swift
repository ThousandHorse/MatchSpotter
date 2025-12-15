//
//  UnifiedLocationListView.swift
//  MatchSpotter
//
//  統合された場所一覧表示ビュー（ローカル + Firestore）
//

import SwiftUI
import SwiftData
import FirebaseFirestore
import OSLog

/// 統合された場所一覧表示ビュー（第2階層）
struct UnifiedLocationListView: View {
    let unifiedPrefecture: UnifiedPrefecture
    @Environment(\.modelContext) private var modelContext
    @Query private var allPrefectures: [Prefecture]
    @StateObject private var firebaseManager = FirebaseManager.shared
    @State private var editingLocation: Location?
    @State private var editedName = ""
    @State private var unifiedLocations: [UnifiedLocation] = []
    @State private var isLoading = false
    @State private var sharedPhotos: [SharedPhoto] = []
    @State private var lastPrefectureDocument: DocumentSnapshot?
    @State private var hasMorePrefecture = false
    @State private var isLoadingMore = false
    @State private var loadErrorMessage: String?
    @State private var prefectureForAddLocation: Prefecture?
    private let logger = Logger(subsystem: "com.thousandhorse.MatchSpotter", category: "UnifiedLocationListView")

    var body: some View {
        ZStack {
            List {
                ForEach(unifiedLocations) { unifiedLocation in
                    NavigationLink {
                        UnifiedPhotoListView(unifiedLocation: unifiedLocation)
                    } label: {
                        UnifiedLocationRowView(unifiedLocation: unifiedLocation)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if let localLocation = unifiedLocation.localLocation {
                            Button(role: .destructive) {
                                deleteLocalLocation(localLocation)
                            } label: {
                                Label("ローカルを削除", systemImage: "trash")
                            }

                            Button {
                                startEditing(localLocation)
                            } label: {
                                Label("編集", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                    .contextMenu {
                        if let localLocation = unifiedLocation.localLocation {
                            Button {
                                startEditing(localLocation)
                            } label: {
                                Label("名前を編集", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                deleteLocalLocation(localLocation)
                            } label: {
                                Label("ローカルデータを削除", systemImage: "trash")
                            }
                        }
                    }
                }

                if hasMorePrefecture {
                    HStack {
                        Spacer()
                        Button {
                            Task {
                                await loadUnifiedLocations(loadMore: true)
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
                }
            }

            if isLoading {
                ProgressView("データを同期中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground).opacity(0.8))
            }
        }
        .navigationTitle(unifiedPrefecture.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        await handleAddLocationButtonTap()
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.pink)
                }
            }
        }
        .sheet(item: $prefectureForAddLocation, onDismiss: {
            Task {
                await loadUnifiedLocations()
            }
        }) { prefecture in
            AddLocationView(prefecture: prefecture)
        }
        .alert("場所名を編集", isPresented: Binding(
            get: { editingLocation != nil },
            set: { if !$0 { editingLocation = nil; editedName = "" } }
        )) {
            TextField("場所名", text: $editedName)
            Button("保存") {
                saveLocationName()
            }
            Button("キャンセル", role: .cancel) {
                editingLocation = nil
                editedName = ""
            }
        } message: {
            Text("新しい場所名を入力してください")
        }
        .overlay {
            if !isLoading && unifiedLocations.isEmpty {
                ContentUnavailableView(
                    "場所がありません",
                    systemImage: "mappin.and.ellipse",
                    description: Text("右上の + ボタンから場所を追加してください")
                )
            }
        }
        .alert("読み込みに失敗しました", isPresented: Binding(
            get: { loadErrorMessage != nil },
            set: { if !$0 { loadErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(loadErrorMessage ?? "読み込みに失敗しました。")
        }
        .task {
            await loadUnifiedLocations()
        }
        .refreshable {
            await loadUnifiedLocations()
        }
    }

    private func loadUnifiedLocations(loadMore: Bool = false) async {
        if loadMore {
            guard hasMorePrefecture, !isLoadingMore else { return }
            isLoadingMore = true
        } else {
            isLoading = true
            lastPrefectureDocument = nil
        }

        do {
            let page = try await firebaseManager.fetchPhotosForPrefecture(
                unifiedPrefecture.name,
                lastDocument: loadMore ? lastPrefectureDocument : nil
            )

            if loadMore {
                sharedPhotos.append(contentsOf: page.photos)
            } else {
                sharedPhotos = page.photos
            }
            lastPrefectureDocument = page.lastDocument
            hasMorePrefecture = page.hasMore

            buildUnifiedLocations(from: sharedPhotos)

            if loadMore {
                isLoadingMore = false
            } else {
                isLoading = false
            }
        } catch {
            logger.error("統合場所読み込みエラー: \(error.localizedDescription)")
            loadErrorMessage = error.localizedDescription
            hasMorePrefecture = false
            if loadMore {
                isLoadingMore = false
            } else {
                isLoading = false
            }
        }
    }

    private func buildUnifiedLocations(from sharedPhotos: [SharedPhoto]) {
        // 場所名ごとにグループ化
        var locationDict: [String: [SharedPhoto]] = [:]
        for photo in sharedPhotos {
            if let locationName = photo.locationName {
                locationDict[locationName, default: []].append(photo)
            }
        }

        var unified: [UnifiedLocation] = []

        // ローカルの場所を追加
        if let localPrefecture = unifiedPrefecture.localPrefecture {
            for localLocation in localPrefecture.locations {
                let firestorePhotos = locationDict[localLocation.name] ?? []

                // ローカルのみの写真（firestoreIdがnil）をカウント
                let localOnlyPhotoCount = localLocation.photos.filter { $0.firestoreId == nil }.count

                // Firestoreの写真数を追加
                let totalCount = localOnlyPhotoCount + firestorePhotos.count

                logger.debug("📊 場所: \(localLocation.name)")
                logger.debug("   ローカルのみ: \(localOnlyPhotoCount)枚")
                logger.debug("   Firestore: \(firestorePhotos.count)枚")
                logger.debug("   合計: \(totalCount)枚")

                unified.append(UnifiedLocation(
                    name: localLocation.name,
                    prefectureName: unifiedPrefecture.name,
                    localLocation: localLocation,
                    photoCount: totalCount,
                    latitude: localLocation.latitude,
                    longitude: localLocation.longitude,
                    createdAt: localLocation.createdAt
                ))

                locationDict.removeValue(forKey: localLocation.name)
            }
        }

        // Firestoreのみに存在する場所を追加
        for (name, photos) in locationDict {
            // 最初の写真の位置情報を使用
            let firstPhoto = photos.first
            unified.append(UnifiedLocation(
                name: name,
                prefectureName: unifiedPrefecture.name,
                localLocation: nil,
                photoCount: photos.count,
                latitude: firstPhoto?.latitude,
                longitude: firstPhoto?.longitude,
                createdAt: firstPhoto?.uploadedAt ?? Date()
            ))
        }

        // 作成日時の降順でソート
        self.unifiedLocations = unified.sorted { $0.createdAt > $1.createdAt }
    }

    private func deleteLocalLocation(_ location: Location) {
        withAnimation {
            modelContext.delete(location)
        }
        do {
            try modelContext.save()
        } catch {
            logger.error("統合場所の削除保存エラー: \(error.localizedDescription)")
        }
        Task {
            await loadUnifiedLocations()
        }
    }

    private func startEditing(_ location: Location) {
        editingLocation = location
        editedName = location.name
    }

    private func saveLocationName() {
        guard let location = editingLocation, !editedName.isEmpty else { return }
        withAnimation {
            location.name = editedName
        }
        do {
            try modelContext.save()
        } catch {
            logger.error("統合場所名変更保存エラー: \(error.localizedDescription)")
        }
        editingLocation = nil
        editedName = ""
        Task {
            await loadUnifiedLocations()
        }
    }

    private func handleAddLocationButtonTap() async {
        logger.debug("🔘 +ボタンがタップされました: \(unifiedPrefecture.name)")
        logger.debug("   allPrefectures数: \(allPrefectures.count)")

        // @Queryから該当するPrefectureを探す
        if let existingPrefecture = allPrefectures.first(where: { $0.name == unifiedPrefecture.name }) {
            prefectureForAddLocation = existingPrefecture
            logger.debug("✅ 既存のPrefectureを使用: \(existingPrefecture.name)")
        } else {
            // なければ新規作成
            logger.debug("📝 新しいPrefectureを作成します: \(unifiedPrefecture.name)")
            let newPrefecture = Prefecture(name: unifiedPrefecture.name)
            modelContext.insert(newPrefecture)

            do {
                try modelContext.save()
                logger.info("✅ Prefecture保存成功")

                // 少し待ってから@Queryの更新を待つ
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒

                // もう一度確認
                if let savedPrefecture = allPrefectures.first(where: { $0.name == unifiedPrefecture.name }) {
                    prefectureForAddLocation = savedPrefecture
                    logger.debug("✅ 保存されたPrefectureを取得しました")
                } else {
                    // まだ@Queryに反映されていない場合、直接使用
                    prefectureForAddLocation = newPrefecture
                    logger.warning("⚠️ @Queryに未反映、作成したPrefectureを直接使用")
                }
            } catch {
                logger.error("❌ Prefectureの作成保存エラー: \(error.localizedDescription)")
            }
        }
    }
}

/// 統合された場所行ビュー
struct UnifiedLocationRowView: View {
    let unifiedLocation: UnifiedLocation

    var body: some View {
        HStack(spacing: 16) {
            // フォルダアイコン表示（容量節約のため写真サムネイルは使用しない）
            Image(systemName: unifiedLocation.localLocation != nil ? "folder.fill" : "folder.fill.badge.person.crop")
                .font(.system(size: 40))
                .foregroundColor(unifiedLocation.localLocation != nil ? .pink : .blue)
                .frame(width: 60, height: 60)

            // 右側の情報
            VStack(alignment: .leading, spacing: 6) {
                // 場所名
                Text(unifiedLocation.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                // 写真枚数
                HStack(spacing: 8) {
                    Text("\(unifiedLocation.photoCount)枚の写真")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)

                    if unifiedLocation.localLocation == nil {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("共有のみ")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }

                // 作成日
                Text(unifiedLocation.createdAt.formatted(.dateTime.year().month().day().locale(Locale(identifier: "ja_JP"))))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    let prefecture = Prefecture(name: "東京都")
    let unifiedPrefecture = UnifiedPrefecture(name: "東京都", localPrefecture: prefecture, photoCount: 10)
    return NavigationStack {
        UnifiedLocationListView(unifiedPrefecture: unifiedPrefecture)
    }
    .modelContainer(for: [Prefecture.self, Location.self, PhotoData.self], inMemory: true)
}
