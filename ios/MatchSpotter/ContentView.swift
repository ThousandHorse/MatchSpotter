//
//  ContentView.swift
//  MatchSpotter
//
//  Created by 千馬拓磨 on 2025/10/27.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager

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

            // 管理者のみ招待コードタブを表示
            if authManager.isAdmin {
                AdminInviteCodeView()
                    .tabItem {
                        Label("招待コード", systemImage: "ticket.fill")
                    }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Prefecture.self, Location.self, PhotoData.self], inMemory: true)
}
