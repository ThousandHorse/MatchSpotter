//
//  GoogleMapView.swift
//  MatchSpotter
//
//  Created by Claude Code
//

import SwiftUI
import GoogleMaps
import SwiftData
import CoreLocation

/// GoogleMapをUIViewRepresentableでラップしたビュー
struct GoogleMapViewRepresentable: UIViewRepresentable {
    let photoSpots: [PhotoSpot]
    @Binding var selectedSpot: PhotoSpot?

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition.camera(withLatitude: 35.6812, longitude: 139.7671, zoom: 12.0)
        let mapView = GMSMapView.map(withFrame: .zero, camera: camera)
        mapView.delegate = context.coordinator

        // マップの設定
        mapView.settings.compassButton = true
        mapView.settings.myLocationButton = true
        mapView.isMyLocationEnabled = true
        mapView.settings.zoomGestures = true
        mapView.settings.scrollGestures = true
        mapView.settings.rotateGestures = true
        mapView.settings.tiltGestures = true

        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        // 既存のマーカーをクリア
        mapView.clear()

        guard !photoSpots.isEmpty else { return }

        // 各スポットにマーカーを配置
        var bounds = GMSCoordinateBounds()
        for spot in photoSpots {
            let marker = GMSMarker()
            marker.position = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
            marker.title = spot.name
            marker.snippet = "\(spot.photos.count)枚の写真"
            marker.userData = spot

            // カスタムマーカーアイコン（カメラアイコン風）
            marker.icon = createCustomMarkerIcon()
            marker.map = mapView

            // 境界を拡張
            bounds = bounds.includingCoordinate(marker.position)
        }

        // すべてのマーカーが表示されるようにカメラを調整
        let update = GMSCameraUpdate.fit(bounds, withPadding: 50.0)
        mapView.moveCamera(update)
    }

    // カスタムマーカーアイコンを作成（カメラアイコン）
    private func createCustomMarkerIcon() -> UIImage {
        let size = CGSize(width: 44, height: 44)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            // 外側の円（半透明の赤）
            UIColor.systemRed.withAlphaComponent(0.3).setFill()
            let outerCircle = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size))
            outerCircle.fill()

            // 内側の円（赤）
            UIColor.systemRed.setFill()
            let innerCircle = UIBezierPath(ovalIn: CGRect(x: 8, y: 8, width: 28, height: 28))
            innerCircle.fill()

            // カメラアイコン（白）
            let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
            if let cameraIcon = UIImage(systemName: "camera.fill", withConfiguration: config) {
                UIColor.white.setFill()
                cameraIcon.withTintColor(.white, renderingMode: .alwaysTemplate)
                    .draw(in: CGRect(x: 14, y: 14, width: 16, height: 16))
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: GoogleMapViewRepresentable

        init(_ parent: GoogleMapViewRepresentable) {
            self.parent = parent
        }

        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            if let spot = marker.userData as? PhotoSpot {
                parent.selectedSpot = spot
            }
            return true
        }

        func mapView(_ mapView: GMSMapView, markerInfoWindow marker: GMSMarker) -> UIView? {
            guard let spot = marker.userData as? PhotoSpot else { return nil }

            let infoWindow = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 80))
            infoWindow.backgroundColor = .systemBackground
            infoWindow.layer.cornerRadius = 8
            infoWindow.layer.shadowColor = UIColor.black.cgColor
            infoWindow.layer.shadowOpacity = 0.3
            infoWindow.layer.shadowOffset = CGSize(width: 0, height: 2)
            infoWindow.layer.shadowRadius = 4

            let titleLabel = UILabel(frame: CGRect(x: 10, y: 10, width: 180, height: 20))
            titleLabel.text = spot.name
            titleLabel.font = .boldSystemFont(ofSize: 16)
            titleLabel.textColor = .label

            let subtitleLabel = UILabel(frame: CGRect(x: 10, y: 35, width: 180, height: 16))
            subtitleLabel.text = "\(spot.photos.count)枚の写真"
            subtitleLabel.font = .systemFont(ofSize: 14)
            subtitleLabel.textColor = .secondaryLabel

            let tapLabel = UILabel(frame: CGRect(x: 10, y: 55, width: 180, height: 14))
            tapLabel.text = "タップして詳細を表示"
            tapLabel.font = .systemFont(ofSize: 12)
            tapLabel.textColor = .systemPink

            infoWindow.addSubview(titleLabel)
            infoWindow.addSubview(subtitleLabel)
            infoWindow.addSubview(tapLabel)

            return infoWindow
        }
    }
}

/// Google Maps表示ビュー - 撮影スポットをマップ上に表示
struct GoogleMapView: View {
    @Query(sort: \PhotoSpot.createdAt, order: .reverse) private var photoSpots: [PhotoSpot]
    @State private var selectedSpot: PhotoSpot?

    var body: some View {
        NavigationStack {
            GoogleMapViewRepresentable(photoSpots: photoSpots, selectedSpot: $selectedSpot)
                .navigationTitle("地図")
                .navigationBarTitleDisplayMode(.inline)
                // スポット選択時に詳細画面をシート表示
                .sheet(item: $selectedSpot) { spot in
                    NavigationStack {
                        PhotoSpotDetailView(spot: spot)
                    }
                    .presentationDetents([.medium, .large])
                }
        }
    }
}

#Preview {
    GoogleMapView()
        .modelContainer(for: [PhotoSpot.self, PhotoData.self], inMemory: true)
}
