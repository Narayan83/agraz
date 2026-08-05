import React, { useEffect, useMemo, useRef, useState } from "react";
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
 * OpenStreetMap + Leaflet. Search uses Nominatim with live autocomplete
 * so small spelling mistakes (e.g. "gogle"/place names) still get suggestions.
 */
export default function ServiceRegistrationMapPicker({ latitude, longitude, onChange }) {
  const [search, setSearch] = useState("");
  const [searching, setSearching] = useState(false);
  const [suggestions, setSuggestions] = useState([]);
  const [showSuggestions, setShowSuggestions] = useState(false);
  const debounceRef = useRef(null);
  const wrapRef = useRef(null);

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

  useEffect(() => {
    const onDocClick = (e) => {
      if (wrapRef.current && !wrapRef.current.contains(e.target)) {
        setShowSuggestions(false);
      }
    };
    document.addEventListener("mousedown", onDocClick);
    return () => document.removeEventListener("mousedown", onDocClick);
  }, []);

  const fetchSuggestions = async (q) => {
    if (!q || q.trim().length < 2) {
      setSuggestions([]);
      return;
    }
    setSearching(true);
    try {
      const url = `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(
        q.trim()
      )}&addressdetails=1&limit=6&countrycodes=in`;
      const res = await fetch(url, {
        headers: { Accept: "application/json" },
      });
      const data = await res.json();
      setSuggestions(Array.isArray(data) ? data : []);
      setShowSuggestions(true);
    } catch {
      setSuggestions([]);
    } finally {
      setSearching(false);
    }
  };

  const onSearchChange = (value) => {
    setSearch(value);
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => fetchSuggestions(value), 350);
  };

  const applyResult = (item) => {
    const lat = parseFloat(item.lat);
    const lon = parseFloat(item.lon);
    if (!Number.isNaN(lat) && !Number.isNaN(lon)) {
      onChange(lat, lon);
      setSearch(item.display_name || search);
      setShowSuggestions(false);
      setSuggestions([]);
    }
  };

  const runSearch = async () => {
    const q = search.trim();
    if (!q) return;
    if (suggestions.length > 0) {
      applyResult(suggestions[0]);
      return;
    }
    setSearching(true);
    try {
      const url = `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(
        q
      )}&limit=1&countrycodes=in`;
      const res = await fetch(url, {
        headers: { Accept: "application/json" },
      });
      const data = await res.json();
      if (data?.[0]) {
        applyResult(data[0]);
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
      <div className="sr-map-search-row" ref={wrapRef} style={{ position: "relative" }}>
        <input
          type="text"
          className="sr-map-search-input"
          placeholder="Search place (autocomplete fixes small spelling mistakes)…"
          value={search}
          onChange={(e) => onSearchChange(e.target.value)}
          onFocus={() => suggestions.length > 0 && setShowSuggestions(true)}
          onKeyDown={(e) => e.key === "Enter" && (e.preventDefault(), runSearch())}
          autoComplete="off"
        />
        <button type="button" className="secondary-btn sr-map-search-btn" onClick={runSearch} disabled={searching}>
          {searching ? "…" : "Search"}
        </button>
        {showSuggestions && suggestions.length > 0 ? (
          <ul
            className="sr-map-suggestions"
            style={{
              position: "absolute",
              left: 0,
              right: 0,
              top: "100%",
              zIndex: 1000,
              margin: 0,
              padding: 0,
              listStyle: "none",
              background: "#fff",
              border: "1px solid #ddd",
              borderRadius: 8,
              maxHeight: 220,
              overflowY: "auto",
              boxShadow: "0 8px 20px rgba(0,0,0,0.12)",
            }}
          >
            {suggestions.map((s) => (
              <li key={`${s.place_id}-${s.osm_id}`}>
                <button
                  type="button"
                  onClick={() => applyResult(s)}
                  style={{
                    display: "block",
                    width: "100%",
                    textAlign: "left",
                    padding: "10px 12px",
                    border: "none",
                    background: "transparent",
                    cursor: "pointer",
                    fontSize: 13,
                    lineHeight: 1.35,
                  }}
                >
                  {s.display_name}
                </button>
              </li>
            ))}
          </ul>
        ) : null}
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
        Click the map or pick a suggestion from autocomplete to set latitude / longitude.
      </p>
    </div>
  );
}
