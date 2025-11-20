//
//  PhotoSpotDetailView.swift
//  MatchSpotter
//
//  Created by 千馬拓磨 on 2025/10/27.
//

import SwiftUI
import SwiftData

/// スポット詳細ビュー - スポット情報と写真をグリッド表示
struct PhotoSpotDetailView: View {
    let spot: PhotoSpot
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var showEditView = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // ヘッダー情報（スポット名、座標、写真数）
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.pink)
                        Text(spot.name)
                            .font(.title2)
                            .bold()
                    }
                    
                    Text("\(spot.photos.count)枚の写真")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("📍 \(spot.latitude, specifier: "%.6f"), \(spot.longitude, specifier: "%.6f")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                Divider()
                
                // 写真グリッド
                if spot.photos.isEmpty {
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
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(spot.photos, id: \.id) { photo in
                            PhotoThumbnailView(photo: photo)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("スポット詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("閉じる") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
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
        .sheet(isPresented: $showEditView) {
            EditPhotoSpotView(spot: spot)
        }
        .confirmationDialog(
            "本当にこのスポットを削除しますか？",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                deleteSpot()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この操作は取り消せません。スポットに紐づく写真もすべて削除されます。")
        }
    }

    // スポットを削除
    private func deleteSpot() {
        modelContext.delete(spot)
        dismiss()
    }
}

/// 写真サムネイルビュー - グリッド内の各写真を表示
struct PhotoThumbnailView: View {
    let photo: PhotoData
    @State private var showingFullScreen = false

    var body: some View {
        Button {
            showingFullScreen = true
        } label: {
            if let uiImage = UIImage(data: photo.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 150, height: 150)
                    .clipped()
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 150, height: 150)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    )
            }
        }
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
                
                if let caption = photo.caption {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("キャプション")
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
    let sampleSpot = PhotoSpot(name: "小田急サザンタワー", latitude: 35.6895, longitude: 139.7006)

    return PhotoSpotDetailView(spot: sampleSpot)
        .modelContainer(for: [PhotoSpot.self, PhotoData.self], inMemory: true)
}