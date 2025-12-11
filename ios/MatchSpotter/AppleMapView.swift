//
//  AppleMapView.swift
//  MatchSpotter
//
//  Created by Claude Code
//

import SwiftUI
import MapKit
import SwiftData

/// Apple Maps表示ビュー - 開発用
struct AppleMapView: View {
    @Query(sort: \Location.createdAt, order: .reverse) private var locations: [Location]
    @State private var selectedLocation: Location?
    @State private var selectedPhotoId: String?
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            Map(position: $cameraPosition) {
                ForEach(locations) { location in
                    ForEach(location.photos, id: \.persistentModelID) { photo in
                        if let lat = photo.latitude, let lon = photo.longitude {
                            Annotation(photo.title ?? location.name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)) {
                                Button {
                                    selectedLocation = location
                                    selectedPhotoId = photo.persistentModelID.hashValue.description
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(Color.red.opacity(0.3))
                                            .frame(width: 44, height: 44)
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 28, height: 28)
                                        Image(systemName: "camera.fill")
                                            .foregroundColor(.white)
                                            .font(.system(size: 14, weight: .bold))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .mapStyle(.standard)
            .navigationBarHidden(true)
            .ignoresSafeArea(edges: .top)
            .sheet(item: $selectedLocation) { location in
                NavigationStack {
                    PhotoListView(location: location, filteredPhotoId: selectedPhotoId)
                }
                .presentationDetents([.medium, .large])
            }
        }
    }
}

#Preview {
    AppleMapView()
        .modelContainer(for: [Prefecture.self, Location.self, PhotoData.self], inMemory: true)
}
