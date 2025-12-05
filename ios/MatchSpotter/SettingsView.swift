//
//  SettingsView.swift
//  MatchSpotter
//
//  Created by Claude Code
//

import SwiftUI

/// 設定画面 - 開発用のみ
struct SettingsView: View {
    @AppStorage("useAppleMap") private var useAppleMap = false

    var body: some View {
        NavigationStack {
            Form {
                Section("マップ設定") {
                    Toggle("Apple Mapを使用", isOn: $useAppleMap)

                    Text(useAppleMap ? "Apple Mapを使用中" : "Google Mapを使用中")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Text("この設定画面は開発版でのみ表示されます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("開発設定")
        }
    }
}

#Preview {
    SettingsView()
}
