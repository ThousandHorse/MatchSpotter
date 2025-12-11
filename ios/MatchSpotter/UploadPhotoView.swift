//
//  UploadPhotoView.swift
//  MatchSpotter
//
//  Created by Claude
//

import SwiftUI
import PhotosUI

/// 写真公開画面
struct UploadPhotoView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firebaseManager = FirebaseManager.shared
    @StateObject private var storageManager = FirebaseStorageManager.shared

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var title = ""
    @State private var caption = ""
    @State private var prefectureName = ""
    @State private var locationName = ""
    @State private var showSuccessAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("写真を選択") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        if let photoData = photoData, let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                        } else {
                            Label("写真を選択", systemImage: "photo.on.rectangle.angled")
                                .foregroundColor(.pink)
                        }
                    }
                    .onChange(of: selectedPhoto) { _, newValue in
                        Task {
                            if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                photoData = data
                            }
                        }
                    }
                }

                Section("写真情報") {
                    TextField("タイトル（必須）", text: $title)
                    TextField("詳細（任意）", text: $caption, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("場所情報") {
                    TextField("都道府県（例: 東京都）", text: $prefectureName)
                    TextField("場所（例: 新宿）", text: $locationName)
                }

                if storageManager.isUploading {
                    Section {
                        VStack(spacing: 8) {
                            ProgressView(value: storageManager.uploadProgress)
                            Text("公開中... \(Int(storageManager.uploadProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("写真を公開")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("公開する") {
                        Task {
                            await uploadPhoto()
                        }
                    }
                    .disabled(photoData == nil || title.isEmpty || storageManager.isUploading)
                }
            }
            .alert("公開完了", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("写真を公開しました")
            }
        }
    }

    private func uploadPhoto() async {
        guard let photoData = photoData,
              let userId = firebaseManager.currentUser?.id else { return }

        do {
            let _ = try await storageManager.uploadPhoto(
                imageData: photoData,
                title: title,
                caption: caption.isEmpty ? nil : caption,
                latitude: nil,
                longitude: nil,
                locationName: locationName.isEmpty ? nil : locationName,
                prefectureName: prefectureName.isEmpty ? nil : prefectureName,
                userId: userId,
                userName: firebaseManager.currentUser?.displayName,
                takenAt: Date()
            )

            showSuccessAlert = true
        } catch {
            print("アップロードエラー: \(error)")
        }
    }
}

#Preview {
    UploadPhotoView()
}
