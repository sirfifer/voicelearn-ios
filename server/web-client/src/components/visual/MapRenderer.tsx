'use client';

import * as React from 'react';
import { MapContainer, TileLayer, Marker, Polyline, Polygon, Popup } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { cn } from '@/lib/utils';
import type { GeoPoint, MapMarker, MapRoute, MapRegion } from '@/types';

// Fix Leaflet default marker icon issue
delete (L.Icon.Default.prototype as unknown as { _getIconUrl?: unknown })._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
  iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
  shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
});

// ===== Types =====

export interface MapConfig {
  center: GeoPoint;
  zoom: number;
  style?: 'standard' | 'historical' | 'physical' | 'satellite' | 'minimal' | 'educational';
  markers?: MapMarker[];
  routes?: MapRoute[];
  regions?: MapRegion[];
  interactive?: boolean;
}

export interface MapRendererProps {
  config: MapConfig;
  className?: string;
  height?: string | number;
}

// ===== Tile URLs =====

function getTileUrl(style: string): string {
  switch (style) {
    case 'satellite':
      return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
    case 'physical':
    case 'terrain':
      return 'https://tiles.stadiamaps.com/tiles/stamen_terrain/{z}/{x}/{y}.png';
    case 'historical':
      return 'https://tiles.stadiamaps.com/tiles/stamen_watercolor/{z}/{x}/{y}.jpg';
    case 'minimal':
      return 'https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}.png';
    case 'standard':
    case 'educational':
    default:
      return 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
  }
}

function getAttribution(style: string): string {
  switch (style) {
    case 'satellite':
      return '&copy; Esri';
    case 'physical':
    case 'terrain':
    case 'historical':
    case 'minimal':
      return '&copy; Stadia Maps, &copy; OpenMapTiles, &copy; OpenStreetMap';
    default:
      return '&copy; OpenStreetMap contributors';
  }
}

// ===== Custom Icon Creator =====

function createIcon(color?: string): L.DivIcon {
  const markerColor = color || '#3b82f6';
  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">
      <path fill="${markerColor}" d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"/>
    </svg>
  `;

  return L.divIcon({
    html: svg,
    className: 'custom-marker',
    iconSize: [24, 24],
    iconAnchor: [12, 24],
    popupAnchor: [0, -24],
  });
}

// ===== Map Renderer Component =====

function MapRenderer({ config, className, height = '400px' }: MapRendererProps) {
  const { center, zoom, style = 'standard', markers, routes, regions, interactive = true } = config;

  const tileUrl = getTileUrl(style);
  const attribution = getAttribution(style);

  return (
    <div
      className={cn('map-container rounded-lg overflow-hidden border', className)}
      style={{ height }}
    >
      <MapContainer
        center={[center.latitude, center.longitude]}
        zoom={zoom}
        className="h-full w-full"
        scrollWheelZoom={interactive}
        dragging={interactive}
        doubleClickZoom={interactive}
        zoomControl={interactive}
      >
        <TileLayer url={tileUrl} attribution={attribution} />

        {/* Render Regions (Polygons) */}
        {regions?.map((region, i) =>
          region.points ? (
            <Polygon
              key={region.id || `region-${i}`}
              positions={region.points.map((p) => [p.latitude, p.longitude])}
              pathOptions={{
                fillColor: region.fillColor || '#3b82f6',
                fillOpacity: region.opacity || 0.3,
                color: region.fillColor || '#3b82f6',
                weight: 2,
              }}
            >
              {region.label && <Popup>{region.label}</Popup>}
            </Polygon>
          ) : null
        )}

        {/* Render Routes (Polylines) */}
        {routes?.map((route, i) => (
          <Polyline
            key={route.id || `route-${i}`}
            positions={route.points.map((p) => [p.latitude, p.longitude])}
            pathOptions={{
              color: route.color || '#3b82f6',
              weight: route.width || 3,
              dashArray: route.style === 'dashed' ? '10, 10' : route.style === 'dotted' ? '2, 8' : undefined,
            }}
          >
            {route.label && <Popup>{route.label}</Popup>}
          </Polyline>
        ))}

        {/* Render Markers */}
        {markers?.map((marker, i) => (
          <Marker
            key={marker.id || `marker-${i}`}
            position={[marker.latitude, marker.longitude]}
            icon={createIcon(marker.color)}
          >
            <Popup>
              <div className="p-1">
                <strong className="block">{marker.label}</strong>
                {marker.description && (
                  <p className="text-sm text-muted-foreground mt-1">{marker.description}</p>
                )}
              </div>
            </Popup>
          </Marker>
        ))}
      </MapContainer>
    </div>
  );
}

export { MapRenderer };
