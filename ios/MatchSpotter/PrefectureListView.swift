//
//  PrefectureListView.swift
//  MatchSpotter
//
//  Created by 千馬拓磨
//

import SwiftUI
import SwiftData
import OSLog

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

    private let logger = Logger(subsystem: "com.thousandhorse.MatchSpotter", category: "PrefectureListView")

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

        logger.debug("🔄 統合エリアデータ読み込み開始（最適化版）")
        logger.debug("   📱 ローカルエリア数: \(self.allPrefectures.count)個")

        // Firestoreから軽量なサマリー情報を取得（全写真読み込みを回避）
        let summaries = await firebaseManager.fetchPrefecturesSummary()
        logger.debug("📊 Firestoreサマリー取得: \(summaries.count)個のエリア")

        // サマリーを辞書化（高速アクセス用）
        var summaryDict: [String: PrefectureSummary] = [:]
        for summary in summaries {
            summaryDict[summary.prefectureName] = summary
            logger.debug("   📍 エリア: \(summary.prefectureName), 写真数: \(summary.photoCount)")
        }

        // ローカルとFirestoreのデータを統合
        var unified: [UnifiedPrefecture] = []

        // まずローカルのPrefectureを追加
        for localPref in allPrefectures {
            let firestorePhotoCount = summaryDict[localPref.name]?.photoCount ?? 0
            let totalCount = localPref.totalPhotoCount + firestorePhotoCount

            // 作成日時は、Firestoreサマリーとローカルの古い方を使用
            var createdAt = localPref.createdAt
            if let summary = summaryDict[localPref.name] {
                createdAt = min(createdAt, summary.firstPhotoUploadedAt)
            }

            unified.append(UnifiedPrefecture(
                name: localPref.name,
                localPrefecture: localPref,
                photoCount: totalCount,
                createdAt: createdAt
            ))

            // 処理済みなので辞書から削除
            summaryDict.removeValue(forKey: localPref.name)
        }

        // Firestoreのみに存在するエリアを追加
        for (name, summary) in summaryDict {
            logger.debug("   🌐 Firestoreのみのエリア: \(name) (\(summary.photoCount)枚)")
            unified.append(UnifiedPrefecture(
                name: name,
                localPrefecture: nil,
                photoCount: summary.photoCount,
                createdAt: summary.firstPhotoUploadedAt
            ))
        }

        logger.info("✅ 統合完了: 合計\(unified.count)個のエリア（最適化により大幅に高速化）")
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
