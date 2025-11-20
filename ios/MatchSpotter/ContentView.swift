//
//  ContentView.swift
//  MatchSpotter
//
//  Created by 千馬拓磨 on 2025/10/27.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            GoogleMapView()
                .tabItem {
                    Label("地図", systemImage: "map")
                }

            PrefectureListView()
                .tabItem {
                    Label("リスト", systemImage: "list.bullet")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Prefecture.self, Location.self, PhotoData.self], inMemory: true)
}
