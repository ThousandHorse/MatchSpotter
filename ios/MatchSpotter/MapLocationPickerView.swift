//
//  MapLocationPickerView.swift
//  MatchSpotter
//
//  Created by Claude Code
//

import SwiftUI
import MapKit

/// 地図上で位置を選択するビュー
struct MapLocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedLatitude: Double?
    @Binding var selectedLongitude: Double?

    @State private var cameraPosition: MapCameraPosition
    @State private var selectedCoordinate: CLLocationCoordinate2D?

    init(selectedLatitude: Binding<Double?>, selectedLongitude: Binding<Double?>) {
        self._selectedLatitude = selectedLatitude
        self._selectedLongitude = selectedLongitude

        // 既存の座標があればそこを中心に、なければ東京駅を初期位置に
        let initialCoordinate: CLLocationCoordinate2D
        if let lat = selectedLatitude.wrappedValue, let lon = selectedLongitude.wrappedValue {
            initialCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        } else {
            initialCoordinate = CLLocationCoordinate2D(latitude: 35.6812, longitude: 139.7671) // 東京駅
        }

        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: initialCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )))

        _selectedCoordinate = State(initialValue: selectedLatitude.wrappedValue != nil && selectedLongitude.wrappedValue != nil ? initialCoordinate : nil)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $cameraPosition) {
                    if let coordinate = selectedCoordinate {
                        Annotation("選択位置", coordinate: coordinate) {
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
                .mapStyle(.standard)
                .onTapGesture { location in
                    // タップした画面座標から地図座標を取得する必要があるため、
                    // MapReaderを使用
                }

                // マップリーダーでタップ位置を取得
                MapReader { proxy in
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { screenCoordinate in
                            if let coordinate = proxy.convert(screenCoordinate, from: .local) {
                                selectedCoordinate = coordinate
                            }
                        }
                }

                // 説明テキスト
                VStack {
                    HStack {
                        Text("地図をタップして位置を設定してください")
                            .font(.caption)
                            .padding(8)
                            .background(Color(.systemBackground).opacity(0.9))
                            .cornerRadius(8)
                            .shadow(radius: 2)
                        Spacer()
                    }
                    .padding()
                    Spacer()
                }

                // 座標表示（デバッグ用）
                if let coordinate = selectedCoordinate {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("緯度: \(coordinate.latitude, specifier: "%.6f")")
                                Text("経度: \(coordinate.longitude, specifier: "%.6f")")
                            }
                            .font(.caption2)
                            .padding(8)
                            .background(Color(.systemBackground).opacity(0.9))
                            .cornerRadius(8)
                            .shadow(radius: 2)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("位置を設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        if let coordinate = selectedCoordinate {
                            selectedLatitude = coordinate.latitude
                            selectedLongitude = coordinate.longitude
                        }
                        dismiss()
                    }
                    .disabled(selectedCoordinate == nil)
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var lat: Double? = 35.6812
    @Previewable @State var lon: Double? = 139.7671

    return MapLocationPickerView(selectedLatitude: $lat, selectedLongitude: $lon)
}
