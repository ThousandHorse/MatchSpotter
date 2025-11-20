//
//  EditLocationView.swift
//  MatchSpotter
//
//  Created by Claude Code
//

import SwiftUI
import SwiftData

/// 場所編集ビュー
struct EditLocationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let location: Location

    @State private var locationName: String = ""

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
            print("保存エラー: \(error)")
        }
    }
}

#Preview {
    let location = Location(name: "新宿")
    return EditLocationView(location: location)
        .modelContainer(for: [Prefecture.self, Location.self, PhotoData.self], inMemory: true)
}
