//
//  MatchSpotterApp.swift
//  MatchSpotter
//
//  Created by 千馬拓磨 on 2025/10/27.
//

import SwiftUI
import SwiftData
import GoogleMaps

@main
struct MatchSpotterApp: App {

    init() {
        // Info.plistからGoogle Maps API Keyを読み込んで初期化
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String {
            GMSServices.provideAPIKey(apiKey)
        }
    }
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            PhotoSpot.self,
            PhotoData.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
