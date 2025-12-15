//
//  UploadingOverlayView.swift
//  MatchSpotter
//
//  アップロード中のオーバーレイUI（再利用可能コンポーネント）
//

import SwiftUI

/// アップロード中のオーバーレイ表示
struct UploadingOverlayView: View {
    let progress: Double
    let isUploading: Bool

    var body: some View {
        if isUploading {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .overlay {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))

                        Text("アップロード中...")
                            .font(.headline)
                            .foregroundColor(.white)

                        // プログレスバー
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .pink))
                            .frame(width: 200)

                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(32)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                }
        }
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        UploadingOverlayView(progress: 0.5, isUploading: true)
    }
}
