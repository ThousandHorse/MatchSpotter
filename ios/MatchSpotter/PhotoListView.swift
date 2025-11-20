//
//  PhotoListView.swift
//  MatchSpotter
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData
import PhotosUI
import CoreLocation
import ImageIO

/// 写真リスト表示ビュー（第3階層）
struct PhotoListView: View {
    let location: Location
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var showEditView = false
    @State private var showDeleteConfirmation = false
    @State private var showAddPhoto = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if location.photos.isEmpty {
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
                    ForEach(location.photos, id: \.id) { photo in
                        PhotoListRowView(photo: photo)
                        if photo.id != location.photos.last?.id {
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
                    Text(photo.takenAt.formatted(date: .long, time: .omitted))
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
        .fullScreenCover(isPresented: $showingFullScreen) {
            PhotoDetailView(photo: photo)
        }
    }
}

/// 写真詳細ビュー - フルスクリーンで写真とキャプションを表示
struct PhotoDetailView: View {
    let photo: PhotoData
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
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
                        Text("タイトル")
                            .font(.headline)
                        Text(title)
                            .font(.body)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let caption = photo.caption {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("詳細")
                            .font(.headline)
                        Text(caption)
                            .font(.body)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("撮影日時")
                        .font(.headline)
                    Text(photo.takenAt, format: .dateTime.day().month().year().hour().minute())
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let location = Location(name: "新宿", latitude: 35.6895, longitude: 139.7006)
    return PhotoListView(location: location)
        .modelContainer(for: [Prefecture.self, Location.self, PhotoData.self], inMemory: true)
}
