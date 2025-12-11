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
    @StateObject private var firebaseManager = FirebaseManager.shared
    #if DEBUG
    @AppStorage("useAppleMap") private var useAppleMap = false
    #endif

    var body: some View {
        Group {
            if firebaseManager.isAuthenticated {
                TabView {
                    // 開発環境では切り替え可能、本番環境ではGoogleMap固定
                    #if DEBUG
                    if useAppleMap {
                        AppleMapView()
                            .tabItem {
                                Label("地図", systemImage: "map")
                            }
                    } else {
                        GoogleMapView()
                            .tabItem {
                                Label("地図", systemImage: "map")
                            }
                    }
                    #else
                    GoogleMapView()
                        .tabItem {
                            Label("地図", systemImage: "map")
                        }
                    #endif

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

                    #if DEBUG
                    SettingsView()
                        .tabItem {
                            Label("設定", systemImage: "gearshape")
                        }
                    #endif
                }
            } else {
                LoginView()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Prefecture.self, Location.self, PhotoData.self], inMemory: true)
}
