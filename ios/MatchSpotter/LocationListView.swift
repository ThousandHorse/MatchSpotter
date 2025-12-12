//
//  LocationListView.swift
//  MatchSpotter
//
//  Created by 千馬拓磨
//

import SwiftUI
import SwiftData
import OSLog

/// 場所一覧表示ビュー（第2階層）
struct LocationListView: View {
    let prefecture: Prefecture
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddLocation = false
    @State private var editingLocation: Location?
    @State private var editedName = ""
    private let logger = Logger(subsystem: "com.thousandhorse.MatchSpotter", category: "LocationListView")

    var body: some View {
        List {
            ForEach(prefecture.locations) { location in
                NavigationLink {
                    PhotoListView(location: location)
                } label: {
                    LocationRowView(location: location)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deleteLocation(location)
                    } label: {
                        Label("削除", systemImage: "trash")
                    }

                    Button {
                        startEditing(location)
                    } label: {
                        Label("編集", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
                .contextMenu {
                    Button {
                        startEditing(location)
                    } label: {
                        Label("名前を編集", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        deleteLocation(location)
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
            }
            .onDelete(perform: deleteLocations)
        }
        .navigationTitle(prefecture.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddLocation = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.pink)
                }
            }
        }
        .sheet(isPresented: $showingAddLocation) {
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
            if prefecture.locations.isEmpty {
                ContentUnavailableView(
                    "場所がありません",
                    systemImage: "mappin.and.ellipse",
                    description: Text("右上の + ボタンから場所を追加してください")
                )
            }
        }
    }

    private func deleteLocations(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(prefecture.locations[index])
            }
        }
        do {
            try modelContext.save()
        } catch {
            logger.error("場所の削除保存エラー: \(error.localizedDescription)")
        }
    }

    private func deleteLocation(_ location: Location) {
        withAnimation {
            modelContext.delete(location)
        }
        do {
            try modelContext.save()
        } catch {
            logger.error("場所の削除保存エラー: \(error.localizedDescription)")
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
            logger.error("場所名変更保存エラー: \(error.localizedDescription)")
        }
        editingLocation = nil
        editedName = ""
    }
}

/// 場所行ビュー
struct LocationRowView: View {
    let location: Location

    var body: some View {
        HStack(spacing: 16) {
            // サムネイル表示（正方形、角丸）
            if let firstPhoto = location.photos.first,
               let uiImage = UIImage(data: firstPhoto.imageData) {
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
                // 場所名
                Text(location.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                // 写真枚数
                Text("\(location.totalPhotoCount)枚の写真")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                // 作成日
                Text(location.createdAt.formatted(.dateTime.year().month().day().locale(Locale(identifier: "ja_JP"))))
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
    return NavigationStack {
        LocationListView(prefecture: prefecture)
    }
    .modelContainer(for: [Prefecture.self, Location.self, PhotoData.self], inMemory: true)
}
