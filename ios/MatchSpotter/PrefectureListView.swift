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
    @Query private var allPrefectures: [Prefecture]
    @State private var showingAddPrefecture = false
    @State private var prefectureName = ""
    @State private var sortOrder: SortOrder = .dateDescending

    enum SortOrder: String, CaseIterable {
        case dateDescending = "作成日（新しい順）"
        case dateAscending = "作成日（古い順）"
        case nameAscending = "名前（昇順）"
        case nameDescending = "名前（降順）"
        case photoCount = "写真数順"
    }

    private var prefectures: [Prefecture] {
        switch sortOrder {
        case .dateDescending:
            return allPrefectures.sorted { $0.createdAt > $1.createdAt }
        case .dateAscending:
            return allPrefectures.sorted { $0.createdAt < $1.createdAt }
        case .nameAscending:
            return allPrefectures.sorted { $0.name < $1.name }
        case .nameDescending:
            return allPrefectures.sorted { $0.name > $1.name }
        case .photoCount:
            return allPrefectures.sorted { $0.totalPhotoCount > $1.totalPhotoCount }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(prefectures) { prefecture in
                    NavigationLink {
                        LocationListView(prefecture: prefecture)
                    } label: {
                        PrefectureRowView(prefecture: prefecture)
                    }
                }
                .onDelete(perform: deletePrefectures)
            }
            .navigationTitle("エリア")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddPrefecture = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.pink)
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
            .overlay {
                if prefectures.isEmpty {
                    ContentUnavailableView(
                        "エリアがありません",
                        systemImage: "map",
                        description: Text("右上の + ボタンからエリアを追加してください")
                    )
                }
            }
        }
    }

    private func addPrefecture() {
        guard !prefectureName.isEmpty else { return }
        let newPrefecture = Prefecture(name: prefectureName)
        modelContext.insert(newPrefecture)
        prefectureName = ""
    }

    private func deletePrefectures(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(prefectures[index])
            }
        }
    }
}

/// 都道府県行ビュー
struct PrefectureRowView: View {
    let prefecture: Prefecture

    var body: some View {
        HStack(spacing: 16) {
            // フォルダアイコン
            Image(systemName: "folder.fill")
                .font(.system(size: 40))
                .foregroundColor(.pink)
                .frame(width: 60, height: 60)

            // エリア名
            Text(prefecture.name)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    PrefectureListView()
        .modelContainer(for: [Prefecture.self, Location.self, PhotoData.self], inMemory: true)
}
