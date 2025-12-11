//
//  MatchSpotterApp.swift
//  MatchSpotter
//
//  Created by 千馬拓磨 on 2025/10/27.
//

import SwiftUI
import SwiftData
import GoogleMaps
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

@main
struct MatchSpotterApp: App {
    @StateObject private var authManager = AuthenticationManager()

    init() {
        // Firebase初期化
        FirebaseApp.configure()

        // Firestoreの設定（オプション）
        let db = Firestore.firestore()
        let settings = FirestoreSettings()
        // キャッシュを有効化してオフライン対応を強化
        settings.isPersistenceEnabled = true
        db.settings = settings

        // Info.plistからGoogle Maps API Keyを読み込んで初期化
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String {
            GMSServices.provideAPIKey(apiKey)
        }
    }
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Prefecture.self,
            Location.self,
            PhotoData.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // モデルスキーマが変更された場合、既存のデータベースを削除して再作成
            print("ModelContainer作成エラー: \(error)")
            print("既存のデータベースを削除して再作成します...")

            // データベースファイルを削除
            let url = modelConfiguration.url
            try? FileManager.default.removeItem(at: url)

            // 再試行
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    ContentView()
                        .environmentObject(authManager)
                } else {
                    LoginView()
                        .environmentObject(authManager)
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
