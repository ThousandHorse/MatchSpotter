//
//  EditLocationView.swift
//  MatchSpotter
//
//  Created by 千馬拓磨
//

import SwiftUI
import SwiftData
import OSLog

/// 場所編集ビュー
struct EditLocationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let location: Location

    @State private var locationName: String = ""

    private let logger = Logger(subsystem: "com.thousandhorse.MatchSpotter", category: "EditLocationView")

    var body: some View {
        NavigationStack {
            Form {
                Section("場所情報") {
                    TextField("場所名", text: $locationName)
                }
            }
            .navigationTitle("場所を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveChanges()
                    }
                }
            }
            .onAppear {
                locationName = location.name
            }
        }
    }

    private func saveChanges() {
        location.name = locationName

        do {
            try modelContext.save()
            dismiss()
        } catch {
            logger.error("保存エラー: \(error.localizedDescription)")
        }
    }
}

#Preview {
    let location = Location(name: "新宿")
    return EditLocationView(location: location)
        .modelContainer(for: [Prefecture.self, Location.self, PhotoData.self], inMemory: true)
}
