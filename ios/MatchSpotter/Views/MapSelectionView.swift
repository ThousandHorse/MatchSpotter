//
//  MapSelectionView.swift
//  MatchSpotter
//
//  地図上で位置を手動選択するビュー
//

import SwiftUI
import GoogleMaps
import CoreLocation

/// 地図上で位置を手動選択するビュー
struct MapSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedLocation: CLLocation?
    let initialLocation: CLLocation? // 初期位置（既存の位置情報がある場合）
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var addressText: String = "地図をタップして場所を選択してください"

    init(selectedLocation: Binding<CLLocation?>, initialLocation: CLLocation? = nil) {
        self._selectedLocation = selectedLocation
        self.initialLocation = initialLocation
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 選択した位置の住所表示
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.pink)
                        Text(addressText)
                            .font(.subheadline)
                            .foregroundColor(selectedCoordinate == nil ? .secondary : .primary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                }
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(.separator)),
                    alignment: .bottom
                )

                // 地図表示
                MapSelectionMapView(
                    selectedCoordinate: $selectedCoordinate,
                    initialLocation: initialLocation,
                    onCoordinateSelected: { coordinate in
                        Task {
                            await reverseGeocode(coordinate)
                        }
                    }
                )
            }
            .navigationTitle("位置を選択")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                // 初期位置がある場合、それを選択状態にする
                if let initial = initialLocation {
                    selectedCoordinate = initial.coordinate
                    await reverseGeocode(initial.coordinate)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("選択") {
                        if let coordinate = selectedCoordinate {
                            selectedLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                        }
                        dismiss()
                    }
                    .disabled(selectedCoordinate == nil)
                }
            }
        }
    }

    /// 座標から住所を取得
    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                var components: [String] = []

                if let name = placemark.name,
                   !name.isEmpty,
                   !name.hasPrefix(placemark.thoroughfare ?? ""),
                   !name.contains("丁目"),
                   !name.contains("番地") {
                    addressText = name
                    return
                }

                if let subLocality = placemark.subLocality {
                    components.append(subLocality)
                }
                if let thoroughfare = placemark.thoroughfare {
                    components.append(thoroughfare)
                }

                if components.isEmpty, let locality = placemark.locality {
                    components.append(locality)
                }

                if components.isEmpty, let administrativeArea = placemark.administrativeArea {
                    components.append(administrativeArea)
                }

                let address = components.joined(separator: " ")
                addressText = address.isEmpty ? "不明な場所" : address
            }
        } catch {
            addressText = "住所の取得に失敗しました"
        }
    }
}

/// Google Maps を使用した地図選択ビュー
struct MapSelectionMapView: UIViewRepresentable {
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    let initialLocation: CLLocation?
    let onCoordinateSelected: (CLLocationCoordinate2D) -> Void

    func makeUIView(context: Context) -> GMSMapView {
        // 初期位置がある場合はそれを使用、なければデフォルト（東京）
        let initialCoordinate: CLLocationCoordinate2D
        let initialZoom: Float

        if let initial = initialLocation {
            initialCoordinate = initial.coordinate
            initialZoom = 15.0 // 既存位置がある場合は少しズームイン
        } else {
            initialCoordinate = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671)
            initialZoom = 12.0
        }

        let camera = GMSCameraPosition.camera(withLatitude: initialCoordinate.latitude,
                                              longitude: initialCoordinate.longitude,
                                              zoom: initialZoom)
        let mapView = GMSMapView.map(withFrame: .zero, camera: camera)
        mapView.delegate = context.coordinator
        mapView.isMyLocationEnabled = true
        mapView.settings.myLocationButton = true

        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        // マーカーを更新
        mapView.clear()

        if let coordinate = selectedCoordinate {
            let marker = GMSMarker(position: coordinate)
            marker.icon = GMSMarker.markerImage(with: .systemPink)
            marker.map = mapView
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: MapSelectionMapView

        init(_ parent: MapSelectionMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D) {
            parent.selectedCoordinate = coordinate
            parent.onCoordinateSelected(coordinate)
        }
    }
}

#Preview {
    MapSelectionView(selectedLocation: .constant(nil))
}
