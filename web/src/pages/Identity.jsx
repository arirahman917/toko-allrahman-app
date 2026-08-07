import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { MapPin, ArrowLeft } from 'lucide-react';

export default function Identity({ identity, setIdentity }) {
  const navigate = useNavigate();
  const [formData, setFormData] = useState({
    name: identity?.name || '',
    address: identity?.address || '',
    lat: identity?.lat || null,
    lng: identity?.lng || null,
    scheduledTime: identity?.scheduledTime || '',
    phone: identity?.phone || ''
  });

  const [loadingLocation, setLoadingLocation] = useState(false);

  const handleGetLocation = () => {
    setLoadingLocation(true);
    if ("geolocation" in navigator) {
      navigator.geolocation.getCurrentPosition(
        function(position) {
          setFormData({
            ...formData,
            lat: position.coords.latitude,
            lng: position.coords.longitude
          });
          setLoadingLocation(false);
        },
        function(error) {
          alert("Gagal mendapatkan lokasi: " + error.message);
          setLoadingLocation(false);
        }
      );
    } else {
      alert("Browser tidak mendukung geolocation");
      setLoadingLocation(false);
    }
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    if (!formData.name || (!formData.address && !formData.lat) || !formData.scheduledTime || !formData.phone) {
      alert("Kolom nama, no hp, alamat/maps, dan waktu pesanan wajib diisi.");
      return;
    }
    setIdentity(formData);
    alert("Identitas berhasil disimpan!");
    navigate('/');
  };

  const InputField = ({ label, type, name, value, onChange, placeholder }) => (
    <div style={{ marginBottom: '16px', position: 'relative' }}>
      {value && (
        <label style={{ 
          position: 'absolute', 
          top: '-8px', 
          left: '12px', 
          backgroundColor: 'white', 
          padding: '0 4px', 
          fontSize: '12px', 
          color: 'var(--color-primary)' 
        }}>
          {label}
        </label>
      )}
      <input 
        type={type} 
        name={name}
        className="input-field" 
        style={{ borderColor: value ? 'var(--color-primary)' : 'var(--color-black)' }}
        placeholder={placeholder}
        value={value}
        onChange={onChange}
      />
    </div>
  );

  return (
    <div style={{ padding: '16px' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '24px' }}>
        <ArrowLeft size={24} onClick={() => navigate(-1)} style={{ cursor: 'pointer' }} />
        <h2 style={{ margin: 0, fontSize: '20px' }}>Identitas Pemesan</h2>
      </div>

      <form onSubmit={handleSubmit}>
        <InputField 
          label="Nama Lengkap" 
          type="text" 
          name="name" 
          placeholder="Nama Lengkap" 
          value={formData.name} 
          onChange={(e) => setFormData({...formData, name: e.target.value})} 
        />
        
        <InputField 
          label="Nomor WhatsApp" 
          type="tel" 
          name="phone" 
          placeholder="08xxxxxxxxxx" 
          value={formData.phone} 
          onChange={(e) => setFormData({...formData, phone: e.target.value})} 
        />

        <div style={{ marginBottom: '16px', position: 'relative' }}>
          {formData.address && (
            <label style={{ position: 'absolute', top: '-8px', left: '12px', backgroundColor: 'white', padding: '0 4px', fontSize: '12px', color: 'var(--color-primary)' }}>Alamat Detail</label>
          )}
          <textarea 
            className="input-field" 
            placeholder="Alamat Detail (Patokan)"
            style={{ minHeight: '80px', borderColor: formData.address ? 'var(--color-primary)' : 'var(--color-black)' }}
            value={formData.address}
            onChange={(e) => setFormData({...formData, address: e.target.value})}
          />
        </div>

        <div style={{ marginBottom: '16px' }}>
          {formData.lat ? (
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px', border: '1px solid var(--color-green)', borderRadius: '8px', backgroundColor: 'rgba(76, 175, 81, 0.1)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--color-green)' }}>
                <MapPin size={20} />
                <span style={{ fontSize: '14px', fontWeight: 'bold' }}>Lokasi Disematkan</span>
              </div>
              <button type="button" onClick={() => setFormData({...formData, lat: null, lng: null})} style={{ background: 'none', border: 'none', color: 'var(--color-red)', cursor: 'pointer', fontWeight: 'bold' }}>X</button>
            </div>
          ) : (
            <button type="button" onClick={handleGetLocation} className="btn" style={{ width: '100%', backgroundColor: 'var(--color-gray-light)', color: 'var(--color-black)', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px' }}>
              <MapPin size={20} />
              {loadingLocation ? "Mengambil Lokasi..." : "Gunakan Lokasi Saat Ini (Maps)"}
            </button>
          )}
        </div>

        <div style={{ marginBottom: '24px', position: 'relative' }}>
          {formData.scheduledTime && (
             <label style={{ position: 'absolute', top: '-8px', left: '12px', backgroundColor: 'white', padding: '0 4px', fontSize: '12px', color: 'var(--color-primary)' }}>Pesanan untuk kapan?</label>
          )}
          <input 
            type="datetime-local" 
            className="input-field" 
            style={{ borderColor: formData.scheduledTime ? 'var(--color-primary)' : 'var(--color-black)' }}
            value={formData.scheduledTime}
            onChange={(e) => setFormData({...formData, scheduledTime: e.target.value})}
          />
          {!formData.scheduledTime && (
            <div style={{ position: 'absolute', top: 14, left: 16, color: '#757575', pointerEvents: 'none' }}>
               Pesanan untuk kapan?
            </div>
          )}
        </div>

        <button type="submit" className="btn btn-primary" style={{ width: '100%' }}>Simpan Identitas</button>
      </form>
    </div>
  );
}
