import React, { useState, useEffect, useRef } from 'react';
import ReactDOM from 'react-dom';
import { MapContainer, TileLayer, Marker, useMap, useMapEvents } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { ArrowLeft, Search, Navigation, Send, MapPin } from 'lucide-react';

// Fix Leaflet's default marker icon issue in React
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
});

// A component to detect map drag and center changes
function MapCenterWatcher({ onCenterChange }) {
  const map = useMap();
  
  useEffect(() => {
    onCenterChange(map.getCenter());
  }, [map, onCenterChange]);

  useMapEvents({
    moveend: () => {
      onCenterChange(map.getCenter());
    },
  });
  return null;
}

// A component to fly map to a specific location
function MapFlyTo({ position }) {
  const map = useMap();
  useEffect(() => {
    if (position) {
      map.flyTo(position, 16, { animate: true });
    }
  }, [map, position]);
  return null;
}

export default function MapPickerModal({ isOpen, onClose, onLocationSelect }) {
  const [center, setCenter] = useState([-6.200000, 106.816666]); // Default Jakarta
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState([]);
  const [isSearching, setIsSearching] = useState(false);
  const [flyTarget, setFlyTarget] = useState(null);
  
  // Try to get GPS location when modal opens
  useEffect(() => {
    if (isOpen) {
      handleGetGPS();
    }
  }, [isOpen]);

  const handleGetGPS = () => {
    if ('geolocation' in navigator) {
      navigator.geolocation.getCurrentPosition(
        (pos) => {
          const newPos = [pos.coords.latitude, pos.coords.longitude];
          setCenter(newPos);
          setFlyTarget(newPos); // triggers animation
        },
        (err) => {
          console.error("GPS Error", err);
        },
        { enableHighAccuracy: true, timeout: 5000 }
      );
    }
  };

  const handleSearch = async () => {
    if (!searchQuery.trim()) return;
    setIsSearching(true);
    try {
      const res = await fetch(`https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(searchQuery)}&limit=5`);
      const data = await res.json();
      setSearchResults(data);
    } catch (e) {
      console.error(e);
      alert('Gagal mencari lokasi');
    } finally {
      setIsSearching(false);
    }
  };

  const selectSearchResult = (result) => {
    const newPos = [parseFloat(result.lat), parseFloat(result.lon)];
    setCenter(newPos);
    setFlyTarget(newPos);
    setSearchResults([]);
    setSearchQuery(result.display_name);
  };

  const handleConfirm = () => {
    // Return "lat,lng"
    onLocationSelect(`${center.lat || center[0]},${center.lng || center[1]}`);
    onClose();
  };

  if (!isOpen) return null;

  return ReactDOM.createPortal(
    <div className="map-modal-overlay">
      <div className="map-modal-content">
        
        {/* Header Search Bar Overlay */}
        <div className="map-search-header">
          <button className="map-back-btn" onClick={onClose}>
            <ArrowLeft size={24} />
          </button>
          <div className="map-search-box">
            <input 
              type="text" 
              placeholder="Cari lokasi, alamat, atau gedung..." 
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && handleSearch()}
            />
            {searchQuery && (
              <button onClick={() => { setSearchQuery(''); setSearchResults([]); }} className="clear-search">✕</button>
            )}
            <button onClick={handleSearch} className="do-search">
              {isSearching ? '...' : <Search size={20} />}
            </button>
          </div>
        </div>

        {/* Search Results Dropdown */}
        {searchResults.length > 0 && (
          <div className="map-search-results">
            {searchResults.map((res, i) => (
              <div key={i} className="map-result-item" onClick={() => selectSearchResult(res)}>
                <MapPin size={18} color="var(--text-muted)" style={{ flexShrink: 0, marginTop: 2 }} />
                <span className="result-text">{res.display_name}</span>
              </div>
            ))}
          </div>
        )}

        {/* The Map itself */}
        <div style={{ flex: 1, position: 'relative' }}>
          <MapContainer center={center} zoom={15} style={{ height: '100%', width: '100%', zIndex: 0 }} zoomControl={false}>
            <TileLayer
              attribution='&copy; <a href="https://osm.org/copyright">OpenStreetMap</a>'
              url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            />
            <MapCenterWatcher onCenterChange={(pos) => setCenter(pos)} />
            <MapFlyTo position={flyTarget} />
            <Marker position={center} />
          </MapContainer>

          {/* Floating Target Icon in center if we want to drag map instead of marker.
              Actually, since we use `Marker position={center}`, the marker is always at the center of the map.
              We can just style it nicely. */}

          {/* GPS Button */}
          <button className="gps-btn" onClick={handleGetGPS}>
            <Navigation size={24} />
          </button>
        </div>

        {/* Bottom Sheet for Confirm */}
        <div className="map-bottom-sheet">
          <div className="sheet-handle"></div>
          
          <button className="share-live-btn" onClick={handleGetGPS}>
            <div className="share-icon-circle">
               <Navigation size={20} color="white" />
            </div>
            <div className="share-text">
               <div style={{ fontSize: 16, fontWeight: 600, color: 'var(--text-main)' }}>Gunakan Lokasi Saat Ini</div>
               <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>Akurat hingga beberapa meter</div>
            </div>
          </button>

          <div style={{ display: 'flex', alignItems: 'center', margin: '16px 0 24px 0' }}>
            <div style={{ flex: 1, height: 1, backgroundColor: 'var(--border-light)' }} />
          </div>

          <button className="confirm-location-btn" onClick={handleConfirm}>
            <MapPin size={20} />
            Kirim Titik Lokasi Ini
          </button>
        </div>
      </div>
    </div>,
    document.body
  );
}
