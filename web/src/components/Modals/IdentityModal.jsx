import React, { useState, useRef, useEffect } from 'react';
import ReactDOM from 'react-dom';
import { X, MapPin, Navigation, Search, CheckCircle } from 'lucide-react';
import MapPickerModal from './MapPickerModal';

/* ── Floating Label Input ── */
function FloatingInput({ icon, label, value, onChange, type = 'text', error, errorMsg }) {
  const [focused, setFocused] = useState(false);
  const hasValue = value && value.length > 0;
  const isFloating = focused || hasValue;

  let borderColor = 'var(--border-light)';
  if (error) borderColor = '#EF4444';
  else if (focused) borderColor = 'var(--primary)';
  else if (hasValue) borderColor = '#1A1D23';

  return (
    <div style={{ marginBottom: 20 }}>
      <div className="floating-row" style={{ marginBottom: error ? 4 : 0 }}>
        <div className="floating-icon">{icon}</div>
        <div className="floating-field" style={{ borderColor }}>
          <label className={`floating-label ${isFloating ? 'floating' : ''}`} style={{
            color: error ? '#EF4444' : focused ? 'var(--primary)' : 'var(--text-muted)'
          }}>
            {label}
          </label>
          <input
            type={type}
            className="floating-input"
            value={value}
            onChange={(e) => onChange(e.target.value)}
            onFocus={() => setFocused(true)}
            onBlur={() => setFocused(false)}
          />
        </div>
      </div>
      {error && (
        <div style={{ fontSize: 12, color: '#EF4444', marginLeft: 44 }}>
          {errorMsg}
        </div>
      )}
    </div>
  );
}

/* ── Floating DateTime Input ── */
function FloatingDateTimeInput({ icon, label, value, onClick, error, errorMsg }) {
  const hasValue = value && value.length > 0;
  const isFloating = hasValue;

  let borderColor = 'var(--border-light)';
  if (error) borderColor = '#EF4444';
  else if (hasValue) borderColor = '#1A1D23';

  // Format display
  const formatDisplay = (val) => {
    if (!val) return '';
    const d = new Date(val);
    const pad = (n) => String(n).padStart(2, '0');
    return `${pad(d.getDate())}/${pad(d.getMonth() + 1)}/${d.getFullYear()} - ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  };

  return (
    <div style={{ marginBottom: 20 }}>
      <div className="floating-row" style={{ marginBottom: error ? 4 : 0 }}>
        <div className="floating-icon">{icon}</div>
        <div
          className="floating-field"
          style={{ borderColor, cursor: 'pointer' }}
          onClick={onClick}
        >
          <label className={`floating-label ${isFloating ? 'floating' : ''}`} style={{
            color: error ? '#EF4444' : 'var(--text-muted)'
          }}>
            {label}
          </label>
          {hasValue && <div className="floating-display-text">{formatDisplay(value)}</div>}
        </div>
      </div>
      {error && (
        <div style={{ fontSize: 12, color: '#EF4444', marginLeft: 44 }}>
          {errorMsg}
        </div>
      )}
    </div>
  );
}

/* ── Custom Date Time Picker Modal ── */
function CustomDateTimePickerModal({ isOpen, onClose, onSave, initialValue }) {
  const [currentMonthDate, setCurrentMonthDate] = useState(() => initialValue ? new Date(initialValue) : new Date());
  const [selectedDate, setSelectedDate] = useState(() => initialValue ? new Date(initialValue) : new Date());
  const [hour, setHour] = useState(() => initialValue ? new Date(initialValue).getHours().toString().padStart(2, '0') : '08');
  const [minute, setMinute] = useState(() => initialValue ? new Date(initialValue).getMinutes().toString().padStart(2, '0') : '00');
  
  const hourRef = useRef(null);
  const minuteRef = useRef(null);
  const scrollTimeout = useRef(null);

  useEffect(() => {
    if (isOpen) {
      setCurrentMonthDate(initialValue ? new Date(initialValue) : new Date());
      setSelectedDate(initialValue ? new Date(initialValue) : new Date());
      setHour(initialValue ? new Date(initialValue).getHours().toString().padStart(2, '0') : '08');
      setMinute(initialValue ? new Date(initialValue).getMinutes().toString().padStart(2, '0') : '00');
      
      setTimeout(() => {
        if (hourRef.current) {
          const idx = hoursList.indexOf(initialValue ? new Date(initialValue).getHours().toString().padStart(2, '0') : '08');
          if (idx >= 0) hourRef.current.scrollTop = idx * 50;
        }
        if (minuteRef.current) {
          const mVal = initialValue ? new Date(initialValue).getMinutes().toString().padStart(2, '0') : '00';
          let idx = minutesList.indexOf(mVal);
          if (idx < 0) {
            minutesList.push(mVal);
            minutesList.sort();
            idx = minutesList.indexOf(mVal);
          }
          if (idx >= 0) minuteRef.current.scrollTop = idx * 50;
        }
      }, 100);
    }
  }, [isOpen, initialValue]);

  if (!isOpen) return null;

  const year = currentMonthDate.getFullYear();
  const month = currentMonthDate.getMonth();
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const firstDay = new Date(year, month, 1).getDay();

  const days = [];
  for (let i = 0; i < firstDay; i++) days.push(null);
  for (let i = 1; i <= daysInMonth; i++) days.push(i);

  const months = ["Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli", "Agustus", "September", "Oktober", "November", "Desember"];

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  // Check if we can go to previous month
  const currentViewMonthStart = new Date(year, month, 1);
  const thisMonthStart = new Date(today.getFullYear(), today.getMonth(), 1);
  const canGoPrev = currentViewMonthStart > thisMonthStart;

  const handlePrevMonth = () => {
    if (canGoPrev) setCurrentMonthDate(new Date(year, month - 1, 1));
  };
  const handleNextMonth = () => setCurrentMonthDate(new Date(year, month + 1, 1));

  const handleSave = () => {
    const finalDate = new Date(selectedDate);
    finalDate.setHours(parseInt(hour, 10));
    finalDate.setMinutes(parseInt(minute, 10));
    onSave(finalDate.toISOString());
    onClose();
  };

  const hoursList = Array.from({ length: 24 }).map((_, i) => i.toString().padStart(2, '0'));
  const minutesList = Array.from({ length: 12 }).map((_, i) => (i * 5).toString().padStart(2, '0'));
  if (!minutesList.includes(minute)) {
    minutesList.push(minute);
    minutesList.sort();
  }

  const handleWheelScroll = (e, list, currentVal, setter) => {
    if (scrollTimeout.current) clearTimeout(scrollTimeout.current);
    const target = e.target;
    scrollTimeout.current = setTimeout(() => {
      const idx = Math.round(target.scrollTop / 50);
      if (list[idx] && list[idx] !== currentVal) {
        setter(list[idx]);
      }
    }, 150);
  };

  const handleHourClick = (h) => {
    setHour(h);
    const idx = hoursList.indexOf(h);
    if (hourRef.current) hourRef.current.scrollTo({ top: idx * 50, behavior: 'smooth' });
  };

  const handleMinuteClick = (m) => {
    setMinute(m);
    const idx = minutesList.indexOf(m);
    if (minuteRef.current) minuteRef.current.scrollTo({ top: idx * 50, behavior: 'smooth' });
  };

  return ReactDOM.createPortal(
    <div className="modal-overlay" onClick={onClose} style={{ zIndex: 200, alignItems: 'center' }}>
      <div className="custom-datetime-modal" onClick={e => e.stopPropagation()}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16, position: 'sticky', top: -24, background: 'white', paddingTop: 24, paddingBottom: 8, zIndex: 10 }}>
          <div style={{ width: 24 }} /> {/* Spacer */}
          <h3 style={{ textAlign: 'center', fontWeight: 700, margin: 0 }}>Pilih Waktu Pesanan</h3>
          <button className="close-btn" style={{ background: 'transparent', border: 'none', cursor: 'pointer' }} onClick={onClose}><X size={24} /></button>
        </div>

        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
          <button className="cal-nav-btn" onClick={handlePrevMonth} disabled={!canGoPrev} style={{ opacity: canGoPrev ? 1 : 0.3 }}>&lt;</button>
          <span style={{ fontWeight: 600, fontSize: 16 }}>{months[month]} {year}</span>
          <button className="cal-nav-btn" onClick={handleNextMonth}>&gt;</button>
        </div>

        <div className="cal-grid">
          {['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'].map(d => (
            <div key={d} className="cal-day-header">{d}</div>
          ))}
          {days.map((d, i) => {
            if (!d) return <div key={`empty-${i}`} />;
            
            const cellDate = new Date(year, month, d);
            const isPast = cellDate < today;
            
            const isSelected = selectedDate.getDate() === d && selectedDate.getMonth() === month && selectedDate.getFullYear() === year;
            const isToday = today.getDate() === d && today.getMonth() === month && today.getFullYear() === year;

            let className = "cal-day-btn";
            if (isSelected) className += " selected";
            else if (isToday) className += " today";
            
            if (isPast) className += " disabled";

            return (
              <button
                key={i}
                className={className}
                disabled={isPast}
                onClick={() => setSelectedDate(cellDate)}
              >
                {d}
              </button>
            );
          })}
        </div>

        <div style={{ height: 1, backgroundColor: 'var(--border-light)', margin: '16px 0' }} />

        <div style={{ padding: '8px 0' }}>
          <div style={{ display: 'flex', justifyContent: 'center', gap: 32 }}>
            
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
              <div style={{ fontSize: 14, fontWeight: 600, color: 'var(--text-muted)', marginBottom: 8 }}>Jam</div>
              <div className="wheel-container">
                <div className="wheel-highlight" />
                <div className="wheel-picker" ref={hourRef} onScroll={(e) => handleWheelScroll(e, hoursList, hour, setHour)}>
                  <div className="wheel-spacer" />
                  {hoursList.map(h => (
                    <div 
                      key={`h-${h}`} 
                      className={`wheel-item ${hour === h ? 'active' : ''}`}
                      onClick={() => handleHourClick(h)}
                    >
                      {h}
                    </div>
                  ))}
                  <div className="wheel-spacer" />
                </div>
              </div>
            </div>

            <div style={{ fontSize: 32, fontWeight: 'bold', display: 'flex', alignItems: 'center', paddingBottom: 0 }}>:</div>

            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
              <div style={{ fontSize: 14, fontWeight: 600, color: 'var(--text-muted)', marginBottom: 8 }}>Menit</div>
              <div className="wheel-container">
                <div className="wheel-highlight" />
                <div className="wheel-picker" ref={minuteRef} onScroll={(e) => handleWheelScroll(e, minutesList, minute, setMinute)}>
                  <div className="wheel-spacer" />
                  {minutesList.map(m => (
                    <div 
                      key={`m-${m}`} 
                      className={`wheel-item ${minute === m ? 'active' : ''}`}
                      onClick={() => handleMinuteClick(m)}
                    >
                      {m}
                    </div>
                  ))}
                  <div className="wheel-spacer" />
                </div>
              </div>
            </div>

          </div>
        </div>

        <div style={{ position: 'sticky', bottom: -24, background: 'white', paddingTop: 16, paddingBottom: 24, zIndex: 10 }}>
          <button className="btn-pesan" onClick={handleSave}>
            Terapkan Waktu
          </button>
        </div>
      </div>
    </div>,
    document.body
  );
}

/* ── Location Option Modal ── */
function LocationOptionModal({ isOpen, onClose, onCurrentLocation, onSearchLocation }) {
  if (!isOpen) return null;
  return ReactDOM.createPortal(
    <div className="modal-overlay" onClick={onClose}>
      <div className="location-option-modal" onClick={e => e.stopPropagation()}>
        <h3 style={{ textAlign: 'center', marginBottom: 8, fontWeight: 700 }}>Pilih Metode Lokasi</h3>
        <p style={{ textAlign: 'center', fontSize: 13, color: 'var(--text-muted)', marginBottom: 24 }}>
          Bagaimana Anda ingin mengirim lokasi?
        </p>
        <div className="location-options-grid">
          <button className="location-option-card" onClick={onCurrentLocation}>
            <div className="location-option-icon-circle" style={{ background: 'linear-gradient(135deg, #3B82F6, #1D4ED8)' }}>
              <Navigation size={24} color="white" />
            </div>
            <span className="location-option-label">Lokasi Saat Ini</span>
            <span className="location-option-desc">Otomatis via GPS</span>
          </button>
          <button className="location-option-card" onClick={onSearchLocation}>
            <div className="location-option-icon-circle" style={{ background: 'linear-gradient(135deg, #10B981, #059669)' }}>
              <Search size={24} color="white" />
            </div>
            <span className="location-option-label">Cari Lokasi</span>
            <span className="location-option-desc">Ketik alamat manual</span>
          </button>
        </div>
        <button className="location-option-cancel" onClick={onClose}>Batal</button>
      </div>
    </div>,
    document.body
  );
}

/* ── Success Confirmation ── */
function SaveSuccessModal({ isOpen, onClose }) {
  if (!isOpen) return null;
  return ReactDOM.createPortal(
    <div className="modal-overlay" onClick={onClose} style={{ justifyContent: 'center', alignItems: 'center' }}>
      <div className="save-success-modal" onClick={e => e.stopPropagation()}>
        <div className="save-success-icon">
          <CheckCircle size={56} color="#10B981" />
        </div>
        <h3 style={{ marginTop: 16, fontWeight: 700 }}>Berhasil!</h3>
        <p style={{ fontSize: 14, color: 'var(--text-muted)', marginTop: 8 }}>Identitas berhasil disimpan</p>
        <button className="btn-pesan" style={{ marginTop: 24 }} onClick={onClose}>OK</button>
      </div>
    </div>,
    document.body
  );
}

/* ── Validation Error Modal ── */
function ValidationErrorModal({ isOpen, onClose, missingFields }) {
  if (!isOpen) return null;
  return ReactDOM.createPortal(
    <div className="modal-overlay" onClick={onClose} style={{ justifyContent: 'center', alignItems: 'center' }}>
      <div className="save-success-modal" onClick={e => e.stopPropagation()}>
        <div style={{ fontSize: 48, marginBottom: 8 }}>⚠️</div>
        <h3 style={{ fontWeight: 700, color: '#EF4444' }}>Data Belum Lengkap</h3>
        <p style={{ fontSize: 14, color: 'var(--text-muted)', marginTop: 8 }}>Kolom berikut wajib diisi:</p>
        <ul style={{ listStyle: 'none', marginTop: 12, padding: 0 }}>
          {missingFields.map((f, i) => (
            <li key={i} style={{ padding: '4px 0', color: '#EF4444', fontWeight: 600, fontSize: 14 }}>• {f}</li>
          ))}
        </ul>
        <button className="btn-pesan" style={{ marginTop: 20 }} onClick={onClose}>Mengerti</button>
      </div>
    </div>,
    document.body
  );
}

/* ── Main IdentityModal ── */
export default function IdentityModal({ isOpen, onClose, identity, onSave }) {
  const [formData, setFormData] = useState({
    name: '', whatsapp: '', address: '', location: null, orderDate: ''
  });
  const [errors, setErrors] = useState({});
  const [showLocationModal, setShowLocationModal] = useState(false);
  const [showDateTimeModal, setShowDateTimeModal] = useState(false);
  const [isLoadingLocation, setIsLoadingLocation] = useState(false);
  const [showSuccess, setShowSuccess] = useState(false);
  const [showValidationError, setShowValidationError] = useState(false);
  const [missingFields, setMissingFields] = useState([]);

  useEffect(() => {
    if (identity) setFormData(identity);
  }, [identity, isOpen]);

  if (!isOpen) return null;

  const handleChange = (field, value) => {
    setFormData(prev => ({ ...prev, [field]: value }));
    if (errors[field]) setErrors(prev => ({ ...prev, [field]: false }));
  };

  const handleGetCurrentLocation = () => {
    setShowLocationModal(false);
    setIsLoadingLocation(true);
    if ('geolocation' in navigator) {
      navigator.geolocation.getCurrentPosition(
        (pos) => {
          setFormData(prev => ({
            ...prev,
            location: `${pos.coords.latitude},${pos.coords.longitude}`
          }));
          setIsLoadingLocation(false);
        },
        (err) => {
          alert('Gagal mengambil lokasi: ' + err.message);
          setIsLoadingLocation(false);
        },
        { enableHighAccuracy: true, timeout: 10000 }
      );
    } else {
      alert('Browser tidak mendukung fitur lokasi');
      setIsLoadingLocation(false);
    }
  };

  const handleSearchLocation = () => {
    setShowLocationModal(false);
    const query = prompt('Masukkan nama tempat atau alamat:');
    if (query) {
      // Use a simple geocoding approach via nominatim (free)
      fetch(`https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(query)}&limit=1`)
        .then(r => r.json())
        .then(data => {
          if (data.length > 0) {
            setFormData(prev => ({
              ...prev,
              location: `${data[0].lat},${data[0].lon}`
            }));
          } else {
            alert('Lokasi tidak ditemukan. Coba kata kunci lain.');
          }
        })
        .catch(() => alert('Gagal mencari lokasi.'));
    }
  };

  const handleRemoveLocation = (e) => {
    e.stopPropagation();
    setFormData(prev => ({ ...prev, location: null }));
  };

  const handleSave = () => {
    const newErrors = {};
    const missing = [];
    if (!formData.name.trim()) { newErrors.name = true; missing.push('Nama'); }
    if (!formData.whatsapp.trim()) { newErrors.whatsapp = true; missing.push('Nomor WhatsApp'); }
    if (!formData.address.trim() && !formData.location) { newErrors.address = true; missing.push('Alamat'); }
    if (!formData.orderDate) { newErrors.orderDate = true; missing.push('Pesanan untuk kapan'); }

    if (missing.length > 0) {
      setErrors(newErrors);
      setMissingFields(missing);
      setShowValidationError(true);
      return;
    }

    onSave(formData);
    setShowSuccess(true);
  };

  const handleSuccessClose = () => {
    setShowSuccess(false);
    onClose();
  };

  return ReactDOM.createPortal(
    <>
      <div className="identity-modal-overlay">
        <div className="identity-modal-content">
          {/* Header */}
          <div className="modal-header" style={{ padding: '24px 24px 0 24px', marginBottom: 16 }}>
            <div style={{ width: 24 }} />
            <h2 className="modal-title">Identitas</h2>
            <button className="close-btn" style={{ background: 'transparent', border: 'none', cursor: 'pointer' }} onClick={onClose}><X size={24} /></button>
          </div>

          {/* Form Body */}
          <div className="identity-form-body" style={{ padding: '12px 24px 0 24px' }}>
            <FloatingInput
              icon={<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z" /></svg>}
              label="Nama"
              value={formData.name}
              onChange={(v) => handleChange('name', v)}
              error={errors.name}
              errorMsg="Isi yaa.."
            />

            <FloatingInput
              icon={<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.127.96.361 1.903.7 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.907.339 1.85.573 2.81.7A2 2 0 0 1 22 16.92Z" /></svg>}
              label="Nomor WhatsApp"
              value={formData.whatsapp}
              onChange={(v) => handleChange('whatsapp', v)}
              type="tel"
              error={errors.whatsapp}
              errorMsg="Isi yaa.."
            />

            <FloatingInput
              icon={<MapPin size={20} />}
              label="Tulis alamat..."
              value={formData.address}
              onChange={(v) => handleChange('address', v)}
              error={errors.address}
              errorMsg="Isi yaa.."
            />

            <div style={{ textAlign: 'center', fontSize: 12, color: 'var(--text-muted)', margin: '4px 0 12px 0' }}>
              Atau (Pilih Salah Satu / Boleh Isi Keduanya)
            </div>

            {/* Location Picker */}
            {formData.location ? (
              <div className="location-result-card">
                <div className="location-result-info">
                  <MapPin size={16} color="var(--primary)" />
                  <span>Lokasi Tersimpan</span>
                </div>
                <button className="location-remove-btn" onClick={handleRemoveLocation}>
                  <X size={16} color="#EF4444" />
                </button>
              </div>
            ) : (
              <button
                className="upload-location-btn"
                onClick={() => setShowLocationModal(true)}
                disabled={isLoadingLocation}
              >
                {isLoadingLocation ? (
                  <span>⏳ Mencari lokasi...</span>
                ) : (
                  <>
                    <MapPin size={16} />
                    <span>Unggah Lokasi Google Maps</span>
                  </>
                )}
              </button>
            )}

            <FloatingDateTimeInput
              icon={<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="3" y="4" width="18" height="18" rx="2" /><path d="M16 2v4M8 2v4M3 10h18" /></svg>}
              label="Pesanan untuk kapan?"
              value={formData.orderDate}
              onClick={() => setShowDateTimeModal(true)}
              error={errors.orderDate}
              errorMsg="Isi yaa.."
            />
          </div>

          {/* Save Button */}
          <div style={{ padding: '16px 24px 24px 24px' }}>
            <button className="btn-pesan" onClick={handleSave}>Simpan</button>
          </div>
        </div>
      </div>

      <LocationOptionModal
        isOpen={showLocationModal}
        onClose={() => setShowLocationModal(false)}
        onCurrentLocation={handleGetCurrentLocation}
        onSearchLocation={handleSearchLocation}
      />

      <SaveSuccessModal
        isOpen={showSuccess}
        onClose={handleSuccessClose}
      />

      <MapPickerModal
        isOpen={showLocationModal}
        onClose={() => setShowLocationModal(false)}
        onLocationSelect={(loc) => {
          handleChange('location', loc);
          setShowLocationModal(false);
        }}
      />

      <CustomDateTimePickerModal
        isOpen={showDateTimeModal}
        onClose={() => setShowDateTimeModal(false)}
        initialValue={formData.orderDate}
        onSave={(v) => handleChange('orderDate', v)}
      />

      <ValidationErrorModal
        isOpen={showValidationError}
        onClose={() => setShowValidationError(false)}
        missingFields={missingFields}
      />
    </>,
    document.body
  );
}
