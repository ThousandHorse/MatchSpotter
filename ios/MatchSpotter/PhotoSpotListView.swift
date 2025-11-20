//
//  PhotoSpotListView.swift
//  MatchSpotter
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData

/// スポット一覧表示ビュー - リスト形式で撮影スポットを表示
struct PhotoSpotListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PhotoSpot.createdAt, order: .reverse) private var photoSpots: [PhotoSpot]
    @State private var showingAddSpot = false
    @State private var editingSpot: PhotoSpot?
    @State private var spotToDelete: PhotoSpot?
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(photoSpots) { spot in
                    NavigationLink {
                        PhotoSpotDetailView(spot: spot)
                    } label: {
                        PhotoSpotRowView(spot: spot)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            editingSpot = spot
                        } label: {
                            Label("編集", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            spotToDelete = spot
                            showDeleteConfirmation = true
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("撮影スポット")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSpot = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSpot) {
                AddPhotoSpotView()
            }
            .sheet(item: $editingSpot) { spot in
                EditPhotoSpotView(spot: spot)
            }
            .confirmationDialog(
                "本当にこのスポットを削除しますか？",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible,
                presenting: spotToDelete
            ) { spot in
                Button("削除", role: .destructive) {
                    deleteSpot(spot)
                }
                Button("キャンセル", role: .cancel) {}
            } message: { spot in
                Text("「\(spot.name)」とその写真（\(spot.photos.count)枚）がすべて削除されます。この操作は取り消せません。")
            }
            // 空の状態の表示
            .overlay {
                if photoSpots.isEmpty {
                    ContentUnavailableView(
                        "スポットがありません",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("右上の + ボタンから撮影スポットを追加してください")
                    )
                }
            }
        }
    }

    // 単一スポットを削除
    private func deleteSpot(_ spot: PhotoSpot) {
        withAnimation {
            modelContext.delete(spot)
        }
        spotToDelete = nil
    }
}

/// スポット行ビュー - リスト内の各行を表示
struct PhotoSpotRowView: View {
    let spot: PhotoSpot

    var body: some View {
        HStack(spacing: 12) {
            // サムネイル表示
            if let firstPhoto = spot.photos.first,
               let uiImage = UIImage(data: firstPhoto.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.gray)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(spot.name)
                    .font(.headline)

                Text("\(spot.photos.count)枚の写真")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(spot.createdAt, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PhotoSpotListView()
        .modelContainer(for: [PhotoSpot.self, PhotoData.self], inMemory: true)
}
