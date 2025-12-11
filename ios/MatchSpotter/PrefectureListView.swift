//
//  PrefectureListView.swift
//  MatchSpotter
//
//  Created by 千馬拓磨
//

import SwiftUI
import SwiftData

/// 都道府県一覧表示ビュー（第1階層）
struct PrefectureListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authManager: AuthenticationManager
    @Query private var allPrefectures: [Prefecture]
    @StateObject private var firebaseManager = FirebaseManager.shared
    @State private var showingAddPrefecture = false
    @State private var prefectureName = ""
    @State private var sortOrder: SortOrder = .dateDescending
    @State private var showingLogoutAlert = false
    @State private var editingPrefecture: Prefecture?
    @State private var editedName = ""
    @State private var unifiedPrefectures: [UnifiedPrefecture] = []
    @State private var isLoadingFirestore = false

    enum SortOrder: String, CaseIterable {
        case dateDescending = "作成日（新しい順）"
        case dateAscending = "作成日（古い順）"
        case nameAscending = "名前（昇順）"
        case nameDescending = "名前（降順）"
        case photoCount = "写真数順"
    }

    private var sortedPrefectures: [UnifiedPrefecture] {
        switch sortOrder {
        case .dateDescending:
            return unifiedPrefectures.sorted { $0.createdAt > $1.createdAt }
        case .dateAscending:
            return unifiedPrefectures.sorted { $0.createdAt < $1.createdAt }
        case .nameAscending:
            return unifiedPrefectures.sorted { $0.name < $1.name }
        case .nameDescending:
            return unifiedPrefectures.sorted { $0.name > $1.name }
        case .photoCount:
            return unifiedPrefectures.sorted { $0.photoCount > $1.photoCount }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    ForEach(sortedPrefectures) { unifiedPrefecture in
                        NavigationLink {
                            UnifiedLocationListView(unifiedPrefecture: unifiedPrefecture)
                        } label: {
                            UnifiedPrefectureRowView(unifiedPrefecture: unifiedPrefecture)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if let localPrefecture = unifiedPrefecture.localPrefecture {
                                Button(role: .destructive) {
                                    deleteLocalPrefecture(localPrefecture)
                                } label: {
                                    Label("ローカルを削除", systemImage: "trash")
                                }

                                Button {
                                    startEditing(localPrefecture)
                                } label: {
                                    Label("編集", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                        .contextMenu {
                            if let localPrefecture = unifiedPrefecture.localPrefecture {
                                Button {
                                    startEditing(localPrefecture)
                                } label: {
                                    Label("名前を編集", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    deleteLocalPrefecture(localPrefecture)
                                } label: {
                                    Label("ローカルデータを削除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                if isLoadingFirestore {
                    ProgressView("データを同期中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground).opacity(0.8))
                }
            }
            .navigationTitle("エリア")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingLogoutAlert = true
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        #if DEBUG
                        // Firestore診断ツール（開発環境のみ）
                        NavigationLink {
                            FirestoreDiagnosticView()
                        } label: {
                            Image(systemName: "stethoscope")
                                .foregroundColor(.blue)
                        }
                        #endif

                        Button {
                            showingAddPrefecture = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.pink)
                        }
                    }
                }
            }
            .alert("新しいエリア", isPresented: $showingAddPrefecture) {
                TextField("エリア名（例. 東京, 大阪）", text: $prefectureName)
                Button("追加") {
                    addPrefecture()
                }
                Button("キャンセル", role: .cancel) {
                    prefectureName = ""
                }
            }
            .alert("ログアウト", isPresented: $showingLogoutAlert) {
                Button("ログアウト", role: .destructive) {
                    handleLogout()
                }
                Button("キャンセル", role: .cancel) { }
            } message: {
                Text("ログアウトしますか?")
            }
            .alert("エリア名を編集", isPresented: Binding(
                get: { editingPrefecture != nil },
                set: { if !$0 { editingPrefecture = nil; editedName = "" } }
            )) {
                TextField("エリア名", text: $editedName)
                Button("保存") {
                    savePrefectureName()
                }
                Button("キャンセル", role: .cancel) {
                    editingPrefecture = nil
                    editedName = ""
                }
            } message: {
                Text("新しいエリア名を入力してください")
            }
            .overlay {
                if !isLoadingFirestore && unifiedPrefectures.isEmpty {
                    ContentUnavailableView(
                        "エリアがありません",
                        systemImage: "map",
                        description: Text("右上の + ボタンからエリアを追加してください")
                    )
                }
            }
            .task {
                await loadUnifiedPrefectures()
            }
            .refreshable {
                await loadUnifiedPrefectures()
            }
        }
    }

    private func addPrefecture() {
        guard !prefectureName.isEmpty else { return }
        let newPrefecture = Prefecture(name: prefectureName)
        modelContext.insert(newPrefecture)
        prefectureName = ""
        Task {
            await loadUnifiedPrefectures()
        }
    }

    private func deleteLocalPrefecture(_ prefecture: Prefecture) {
        withAnimation {
            modelContext.delete(prefecture)
        }
        Task {
            await loadUnifiedPrefectures()
        }
    }

    private func loadUnifiedPrefectures() async {
        isLoadingFirestore = true

        print("🔄 統合エリアデータ読み込み開始")
        print("   📱 ローカルエリア数: \(allPrefectures.count)個")

        // Firestoreから全ての写真を取得
        let allSharedPhotos = await firebaseManager.fetchPhotos(filter: .all)
        print("📸 Firestoreから取得した写真数: \(allSharedPhotos.count)件")

        // エリア名ごとにグループ化
        var prefectureDict: [String: (photos: [SharedPhoto], createdAt: Date)] = [:]

        for photo in allSharedPhotos {
            if let prefName = photo.prefectureName {
                print("   📍 エリア: \(prefName), タイトル: \(photo.title)")
                if prefectureDict[prefName] == nil {
                    prefectureDict[prefName] = (photos: [photo], createdAt: photo.uploadedAt)
                } else {
                    prefectureDict[prefName]?.photos.append(photo)
                    // 最も古い作成日を保持
                    if photo.uploadedAt < prefectureDict[prefName]!.createdAt {
                        prefectureDict[prefName]?.createdAt = photo.uploadedAt
                    }
                }
            } else {
                print("   ⚠️ エリア名がnullの写真: \(photo.title)")
            }
        }

        print("📊 Firestoreのエリア数: \(prefectureDict.count)個")

        // ローカルとFirestoreのデータを統合
        var unified: [UnifiedPrefecture] = []

        // まずローカルのPrefectureを追加
        for localPref in allPrefectures {
            let firestorePhotos = prefectureDict[localPref.name]?.photos ?? []
            let totalCount = localPref.totalPhotoCount + firestorePhotos.count

            unified.append(UnifiedPrefecture(
                name: localPref.name,
                localPrefecture: localPref,
                photoCount: totalCount,
                createdAt: localPref.createdAt
            ))

            // 処理済みなので辞書から削除
            prefectureDict.removeValue(forKey: localPref.name)
        }

        // Firestoreのみに存在するエリアを追加
        for (name, data) in prefectureDict {
            print("   🌐 Firestoreのみのエリア: \(name) (\(data.photos.count)枚)")
            unified.append(UnifiedPrefecture(
                name: name,
                localPrefecture: nil,
                photoCount: data.photos.count,
                createdAt: data.createdAt
            ))
        }

        print("✅ 統合完了: 合計\(unified.count)個のエリア")
        self.unifiedPrefectures = unified
        isLoadingFirestore = false
    }

    private func startEditing(_ prefecture: Prefecture) {
        editingPrefecture = prefecture
        editedName = prefecture.name
    }

    private func savePrefectureName() {
        guard let prefecture = editingPrefecture, !editedName.isEmpty else { return }
        withAnimation {
            prefecture.name = editedName
        }
        editingPrefecture = nil
        editedName = ""
        Task {
            await loadUnifiedPrefectures()
        }
    }

    private func handleLogout() {
        do {
            try authManager.signOut()
        } catch {
            print("ログアウトエラー: \(error.localizedDescription)")
        }
    }
}

/// 統合された都道府県行ビュー
struct UnifiedPrefectureRowView: View {
    let unifiedPrefecture: UnifiedPrefecture

    var body: some View {
        HStack(spacing: 16) {
            // フォルダアイコン
            Image(systemName: unifiedPrefecture.localPrefecture != nil ? "folder.fill" : "folder.fill.badge.person.crop")
                .font(.system(size: 40))
                .foregroundColor(unifiedPrefecture.localPrefecture != nil ? .pink : .blue)
                .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 4) {
                // エリア名
                Text(unifiedPrefecture.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                // 写真数とソース表示
                HStack(spacing: 8) {
                    Text("\(unifiedPrefecture.photoCount)枚の写真")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if unifiedPrefecture.localPrefecture == nil {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("共有のみ")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    PrefectureListView()
        .modelContainer(for: [Prefecture.self, Location.self, PhotoData.self], inMemory: true)
}
