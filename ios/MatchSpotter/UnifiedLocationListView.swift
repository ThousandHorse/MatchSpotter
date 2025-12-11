//
//  UnifiedLocationListView.swift
//  MatchSpotter
//
//  統合された場所一覧表示ビュー（ローカル + Firestore）
//

import SwiftUI
import SwiftData

/// 統合された場所一覧表示ビュー（第2階層）
struct UnifiedLocationListView: View {
    let unifiedPrefecture: UnifiedPrefecture
    @Environment(\.modelContext) private var modelContext
    @StateObject private var firebaseManager = FirebaseManager.shared
    @State private var showingAddLocation = false
    @State private var editingLocation: Location?
    @State private var editedName = ""
    @State private var unifiedLocations: [UnifiedLocation] = []
    @State private var isLoading = false

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
                    showingAddLocation = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.pink)
                }
            }
        }
        .sheet(isPresented: $showingAddLocation) {
            if let localPrefecture = unifiedPrefecture.localPrefecture {
                AddLocationView(prefecture: localPrefecture)
            }
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
        .task {
            await loadUnifiedLocations()
        }
        .refreshable {
            await loadUnifiedLocations()
        }
    }

    private func loadUnifiedLocations() async {
        isLoading = true

        // Firestoreから該当エリアの写真を取得
        let sharedPhotos = await firebaseManager.fetchPhotosForPrefecture(unifiedPrefecture.name)

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
                let totalCount = localLocation.totalPhotoCount + firestorePhotos.count

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
        isLoading = false
    }

    private func deleteLocalLocation(_ location: Location) {
        withAnimation {
            modelContext.delete(location)
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
        editingLocation = nil
        editedName = ""
        Task {
            await loadUnifiedLocations()
        }
    }
}

/// 統合された場所行ビュー
struct UnifiedLocationRowView: View {
    let unifiedLocation: UnifiedLocation

    var body: some View {
        HStack(spacing: 16) {
            // サムネイル表示（ローカルの場合は最初の写真、共有のみの場合はアイコン）
            if let localLocation = unifiedLocation.localLocation,
               let firstPhoto = localLocation.photos.first,
               let uiImage = UIImage(data: firstPhoto.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(unifiedLocation.localLocation != nil ? Color.gray.opacity(0.2) : Color.blue.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay {
                        Image(systemName: unifiedLocation.localLocation != nil ? "photo" : "person.2.fill")
                            .font(.title2)
                            .foregroundStyle(unifiedLocation.localLocation != nil ? .gray : .blue)
                    }
            }

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
