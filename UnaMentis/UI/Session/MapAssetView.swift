// UnaMentis - Map Asset View
// Display geographic content with static images and interactive MapKit exploration
//
// Part of UI/UX (TDD Section 10)

import MapKit
import SwiftUI

// MARK: - Map Asset View

/// View for displaying map assets in curriculum content
/// Supports both static map images and interactive MapKit exploration
struct MapAssetView: View {
    let asset: VisualAsset
    let imageData: Data?
    let isLoading: Bool
    let loadError: String?
    @Binding var isFullscreen: Bool

    var body: some View {
        VStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .frame(height: 150)
            } else if let error = loadError {
                MapErrorView(error: error)
            } else if let data = imageData, let uiImage = platformImage(from: data) {
                // Static map image with interactive overlay button
                Button {
                    isFullscreen = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        // Interactive map button
                        if asset.mapIsInteractive {
                            Image(systemName: "map.fill")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(Circle().fill(.blue))
                                .padding(8)
                        }
                    }
                }
                .buttonStyle(.plain)
            } else if asset.mapIsInteractive, let coords = mapCoordinates {
                // Interactive MapKit view (fallback when no static image)
                MiniMapView(
                    latitude: coords.latitude,
                    longitude: coords.longitude,
                    zoom: asset.mapZoom,
                    markers: asset.mapMarkers
                )
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onTapGesture {
                    isFullscreen = true
                }
            } else {
                MapPlaceholderView(asset: asset)
            }

            // Title and caption
            if let title = asset.title {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }

            if let caption = asset.caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(asset.altText ?? asset.title ?? "Map")
        .accessibilityHint(asset.mapIsInteractive ? "Double tap to explore interactively" : "Double tap to view fullscreen")
    }

    private var mapCoordinates: CLLocationCoordinate2D? {
        guard let lat = asset.mapCenterLatitude,
              let lon = asset.mapCenterLongitude else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    #if os(iOS)
    private func platformImage(from data: Data) -> UIImage? {
        UIImage(data: data)
    }
    #else
    private func platformImage(from data: Data) -> NSImage? {
        NSImage(data: data)
    }
    #endif
}

// MARK: - Mini Map View

/// Compact MapKit view for inline display
struct MiniMapView: View {
    let latitude: Double
    let longitude: Double
    let zoom: Int
    let markers: [MapMarkerData]

    @State private var position: MapCameraPosition

    init(
        latitude: Double,
        longitude: Double,
        zoom: Int,
        markers: [MapMarkerData]
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.zoom = zoom
        self.markers = markers

        // Calculate span from zoom level
        let span = Self.zoomToSpan(zoom)
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        )
        _position = State(initialValue: .region(region))
    }

    var body: some View {
        Map(position: $position, interactionModes: []) {
            ForEach(markers, id: \.id) { marker in
                Marker(marker.label, coordinate: marker.coordinate)
                    .tint(.red)
            }
        }
        .mapStyle(.standard)
    }

    static func zoomToSpan(_ zoom: Int) -> Double {
        // Approximate conversion from zoom level to span
        let zoomToSpan: [Int: Double] = [
            1: 180, 2: 90, 3: 45, 4: 22.5, 5: 11.25,
            6: 5.6, 7: 2.8, 8: 1.4, 9: 0.7, 10: 0.35,
            11: 0.17, 12: 0.085, 13: 0.042, 14: 0.021,
            15: 0.01, 16: 0.005, 17: 0.0025, 18: 0.00125,
        ]
        return zoomToSpan[zoom] ?? 5.0
    }
}

// MARK: - Map Marker Data

/// Data structure for map markers
struct MapMarkerData: Identifiable {
    let id: String
    let label: String
    let coordinate: CLLocationCoordinate2D
    let icon: String?
    let color: Color

    init(
        id: String = UUID().uuidString,
        label: String,
        latitude: Double,
        longitude: Double,
        icon: String? = nil,
        color: Color = .red
    ) {
        self.id = id
        self.label = label
        self.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        self.icon = icon
        self.color = color
    }
}

// MARK: - Map Error View

struct MapErrorView: View {
    let error: String

    var body: some View {
        VStack {
            Image(systemName: "map.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(height: 150)
    }
}

// MARK: - Map Placeholder View

struct MapPlaceholderView: View {
    let asset: VisualAsset

    var body: some View {
        VStack {
            Image(systemName: "map")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            if let title = asset.title {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.1))
        }
    }
}

// MARK: - Fullscreen Map View

/// Fullscreen interactive map view with MapKit exploration
struct FullscreenMapView: View {
    let asset: VisualAsset
    let imageData: Data?
    @Environment(\.dismiss) private var dismiss

    @State private var position: MapCameraPosition
    @State private var showStaticImage = false
    @State private var mapStyle: MapStyleOption = .standard

    init(asset: VisualAsset, imageData: Data?) {
        self.asset = asset
        self.imageData = imageData

        // Initialize map position
        let lat = asset.mapCenterLatitude ?? 0
        let lon = asset.mapCenterLongitude ?? 0
        let span = MiniMapView.zoomToSpan(asset.mapZoom)
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        )
        _position = State(initialValue: .region(region))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if showStaticImage, let data = imageData {
                    StaticMapImageView(data: data)
                } else if asset.mapIsInteractive {
                    InteractiveMapContent(
                        position: $position,
                        mapStyle: mapStyle,
                        markers: asset.mapMarkers,
                        routes: asset.mapRoutes
                    )
                } else if let data = imageData {
                    StaticMapImageView(data: data)
                } else {
                    Text("Map not available")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(asset.title ?? "Map")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                if asset.mapIsInteractive && imageData != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showStaticImage.toggle()
                        } label: {
                            Image(systemName: showStaticImage ? "map" : "photo")
                        }
                    }
                }

                if asset.mapIsInteractive && !showStaticImage {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            ForEach(MapStyleOption.allCases, id: \.self) { style in
                                Button {
                                    mapStyle = style
                                } label: {
                                    Label(style.displayName, systemImage: style.iconName)
                                }
                            }
                        } label: {
                            Image(systemName: "map.fill")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Interactive Map Content

struct InteractiveMapContent: View {
    @Binding var position: MapCameraPosition
    let mapStyle: MapStyleOption
    let markers: [MapMarkerData]
    let routes: [MapRouteData]

    var body: some View {
        Map(position: $position) {
            // Markers
            ForEach(markers, id: \.id) { marker in
                Marker(marker.label, coordinate: marker.coordinate)
                    .tint(marker.color)
            }

            // Routes
            ForEach(routes, id: \.id) { route in
                MapPolyline(coordinates: route.points)
                    .stroke(route.color, lineWidth: route.width)
            }
        }
        .mapStyle(mapStyle.toMapStyle())
        .mapControls {
            MapCompass()
            MapScaleView()
            MapUserLocationButton()
        }
    }
}

// MARK: - Static Map Image View

struct StaticMapImageView: View {
    let data: Data

    var body: some View {
        #if os(iOS)
        if let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        }
        #else
        if let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        }
        #endif
    }
}

// MARK: - Map Route Data

/// Data structure for map routes/paths
struct MapRouteData: Identifiable {
    let id: String
    let label: String
    let points: [CLLocationCoordinate2D]
    let color: Color
    let width: CGFloat

    init(
        id: String = UUID().uuidString,
        label: String,
        points: [(Double, Double)],
        color: Color = .blue,
        width: CGFloat = 3.0
    ) {
        self.id = id
        self.label = label
        self.points = points.map { CLLocationCoordinate2D(latitude: $0.0, longitude: $0.1) }
        self.color = color
        self.width = width
    }
}

// MARK: - Map Style Option

enum MapStyleOption: String, CaseIterable {
    case standard
    case satellite
    case hybrid

    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .satellite: return "Satellite"
        case .hybrid: return "Hybrid"
        }
    }

    var iconName: String {
        switch self {
        case .standard: return "map"
        case .satellite: return "globe.americas"
        case .hybrid: return "map.circle"
        }
    }

    func toMapStyle() -> MapStyle {
        switch self {
        case .standard: return .standard
        case .satellite: return .imagery
        case .hybrid: return .hybrid
        }
    }
}

// MARK: - VisualAsset Map Extensions

extension VisualAsset {
    /// Whether this map supports interactive exploration
    var mapIsInteractive: Bool {
        // Check if the asset has interactive flag set
        // For now, default to true if we have coordinates
        return mapCenterLatitude != nil && mapCenterLongitude != nil
    }

    /// Map center latitude (from metadata)
    var mapCenterLatitude: Double? {
        // Parse from metadata or geography field
        // This would need to be stored in Core Data or parsed from metadata
        return nil
    }

    /// Map center longitude (from metadata)
    var mapCenterLongitude: Double? {
        return nil
    }

    /// Map zoom level
    var mapZoom: Int {
        return 5
    }

    /// Map markers
    var mapMarkers: [MapMarkerData] {
        return []
    }

    /// Map routes
    var mapRoutes: [MapRouteData] {
        return []
    }
}

// MARK: - Preview

#Preview("Map Asset View") {
    VStack {
        Text("Map Asset Views")
            .font(.headline)

        MapPlaceholderView(asset: {
            // Would need mock VisualAsset here
            fatalError("Preview requires mock data")
        }())
    }
    .padding()
}
