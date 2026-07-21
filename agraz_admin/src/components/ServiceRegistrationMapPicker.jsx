import React, { useEffect, useMemo, useState } from "react";
import { MapContainer, TileLayer, Marker, useMap, useMapEvents } from "react-leaflet";
import L from "leaflet";
import icon from "leaflet/dist/images/marker-icon.png";
import iconRetina from "leaflet/dist/images/marker-icon-2x.png";
import iconShadow from "leaflet/dist/images/marker-shadow.png";

import "leaflet/dist/leaflet.css";

delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: iconRetina,
  iconUrl: icon,
  shadowUrl: iconShadow,
});

const DEFAULT_CENTER = [20.5937, 78.9629];

function MapRecenter({ lat, lng }) {
  const map = useMap();
  useEffect(() => {
    if (lat != null && lng != null && !Number.isNaN(lat) && !Number.isNaN(lng)) {
      map.setView([lat, lng], Math.max(map.getZoom(), 13));
    }
  }, [lat, lng, map]);
  return null;
}

function ClickHandler({ onPick }) {
  useMapEvents({
    click(e) {
      onPick(e.latlng.lat, e.latlng.lng);
    },
  });
  return null;
}

/**
 * OpenStreetMap + Leaflet. Search uses Nominatim (no Google Maps API key).
 * Set lat/lng by clicking the map or using search.
 */
export default function ServiceRegistrationMapPicker({ latitude, longitude, onChange }) {
  const [search, setSearch] = useState("");
  const [searching, setSearching] = useState(false);

  const hasPin = useMemo(() => {
    return (
      latitude != null &&
      longitude != null &&
      !Number.isNaN(Number(latitude)) &&
      !Number.isNaN(Number(longitude))
    );
  }, [latitude, longitude]);

  const center = hasPin ? [Number(latitude), Number(longitude)] : DEFAULT_CENTER;
  const zoom = hasPin ? 13 : 5;

  const runSearch = async () => {
    const q = search.trim();
    if (!q) return;
    setSearching(true);
    try {
      const url = `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(
        q
      )}&limit=1`;
      const res = await fetch(url, {
        headers: { Accept: "application/json" },
      });
      const data = await res.json();
      if (data?.[0]) {
        const lat = parseFloat(data[0].lat);
        const lon = parseFloat(data[0].lon);
        if (!Number.isNaN(lat) && !Number.isNaN(lon)) {
          onChange(lat, lon);
        }
      } else {
        alert("No results. Try a different place name.");
      }
    } catch {
      alert("Search failed. Check your network or try again.");
    } finally {
      setSearching(false);
    }
  };

  return (
    <div className="sr-map-picker">
      <div className="sr-map-search-row">
        <input
          type="text"
          className="sr-map-search-input"
          placeholder="Search place (e.g. city, area name)…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && (e.preventDefault(), runSearch())}
        />
        <button type="button" className="secondary-btn sr-map-search-btn" onClick={runSearch} disabled={searching}>
          {searching ? "…" : "Search"}
        </button>
      </div>
      <MapContainer
        center={center}
        zoom={zoom}
        className="sr-map-container"
        scrollWheelZoom
        style={{ height: 260, width: "100%" }}
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        <ClickHandler
          onPick={(lat, lng) => {
            onChange(lat, lng);
          }}
        />
        {hasPin ? <Marker position={[Number(latitude), Number(longitude)]} /> : null}
        {hasPin ? <MapRecenter lat={Number(latitude)} lng={Number(longitude)} /> : null}
      </MapContainer>
      <p className="sr-map-note">
        Map: OpenStreetMap (Leaflet). Click to drop/update the pin. Search uses the free Nominatim geocoder — no Google API key required.
      </p>
    </div>
  );
}
