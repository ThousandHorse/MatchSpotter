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
    let locations: [Location]
    @Binding var selectedLocation: Location?

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

        guard !locations.isEmpty else { return }

        // 各場所にマーカーを配置（座標がある場所のみ）
        var bounds = GMSCoordinateBounds()
        for location in locations {
            // 座標がない場合はスキップ
            guard let coordinate = location.coordinate else { continue }

            let marker = GMSMarker()
            marker.position = coordinate
            marker.title = location.name
            marker.snippet = "\(location.photos.count)枚の写真"
            marker.userData = location

            // カスタムマーカーアイコン（カメラアイコン風）
            marker.icon = createCustomMarkerIcon()
            marker.groundAnchor = CGPoint(x: 0.5, y: 0.5) // 中央をアンカーポイントに設定
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
        let size: CGFloat = 44
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))

        return renderer.image { context in
            let center = CGPoint(x: size / 2, y: size / 2)

            // 外側の円（半透明の赤）
            let outerRadius: CGFloat = size / 2
            let outerCircle = UIBezierPath(arcCenter: center, radius: outerRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            UIColor.systemRed.withAlphaComponent(0.3).setFill()
            outerCircle.fill()

            // 内側の円（赤）
            let innerRadius: CGFloat = 14 // (28 / 2)
            let innerCircle = UIBezierPath(arcCenter: center, radius: innerRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            UIColor.systemRed.setFill()
            innerCircle.fill()

            // カメラアイコン（白）
            let iconSize: CGFloat = 16
            let config = UIImage.SymbolConfiguration(pointSize: iconSize, weight: .bold)
            if let cameraIcon = UIImage(systemName: "camera.fill", withConfiguration: config) {
                let iconRect = CGRect(
                    x: center.x - iconSize / 2,
                    y: center.y - iconSize / 2,
                    width: iconSize,
                    height: iconSize
                )
                cameraIcon.withTintColor(.white, renderingMode: .alwaysTemplate)
                    .draw(in: iconRect)
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
            if let location = marker.userData as? Location {
                parent.selectedLocation = location
            }
            return true
        }

        func mapView(_ mapView: GMSMapView, markerInfoWindow marker: GMSMarker) -> UIView? {
            guard let location = marker.userData as? Location else { return nil }

            let infoWindow = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 80))
            infoWindow.backgroundColor = .systemBackground
            infoWindow.layer.cornerRadius = 8
            infoWindow.layer.shadowColor = UIColor.black.cgColor
            infoWindow.layer.shadowOpacity = 0.3
            infoWindow.layer.shadowOffset = CGSize(width: 0, height: 2)
            infoWindow.layer.shadowRadius = 4

            let titleLabel = UILabel(frame: CGRect(x: 10, y: 10, width: 180, height: 20))
            titleLabel.text = location.name
            titleLabel.font = .boldSystemFont(ofSize: 16)
            titleLabel.textColor = .label

            let subtitleLabel = UILabel(frame: CGRect(x: 10, y: 35, width: 180, height: 16))
            subtitleLabel.text = "\(location.photos.count)枚の写真"
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

/// Google Maps表示ビュー - 場所をマップ上に表示
struct GoogleMapView: View {
    @Query(sort: \Location.createdAt, order: .reverse) private var locations: [Location]
    @State private var selectedLocation: Location?

    var body: some View {
        NavigationStack {
            GoogleMapViewRepresentable(locations: locations, selectedLocation: $selectedLocation)
                .navigationTitle("地図")
                .navigationBarTitleDisplayMode(.inline)
                // 場所選択時に詳細画面をシート表示
                .sheet(item: $selectedLocation) { location in
                    NavigationStack {
                        PhotoListView(location: location)
                    }
                    .presentationDetents([.medium, .large])
                }
        }
    }
}

#Preview {
    GoogleMapView()
        .modelContainer(for: [Prefecture.self, Location.self, PhotoData.self], inMemory: true)
}
