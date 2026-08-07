import React from 'react';
import { Check, MessageCircle } from 'lucide-react';

export default function SuccessModal({ isOpen, onClose }) {
  if (!isOpen) return null;

  const handleWhatsApp = () => {
    // WA Number provided by user: 085794372178
    const waUrl = "https://wa.me/6285794372178?text=Halo%20Toko%20All%20Rahman,%20saya%20telah%20membuat%20pesanan%20baru%20di%20aplikasi%20web.";
    window.open(waUrl, '_blank');
  };

  return (
    <div className="modal-overlay" style={{ zIndex: 200 }}>
      <div className="modal-content centered" style={{ textAlign: 'center', padding: '32px 24px' }}>
        
        <div style={{ 
          width: 64, height: 64, 
          backgroundColor: '#10B981', 
          borderRadius: '50%', 
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          margin: '0 auto 16px auto'
        }}>
          <Check color="white" size={40} strokeWidth={3} />
        </div>

        <h2 style={{ fontSize: 24, fontWeight: 'bold', marginBottom: 12 }}>Berhasil</h2>
        
        <p style={{ color: 'var(--text-main)', fontSize: 16, marginBottom: 32, lineHeight: 1.5 }}>
          Pesanan telah terkirim ke toko Al Rahman
        </p>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <button 
            className="btn-pesan" 
            style={{ width: '100%' }}
            onClick={onClose}
          >
            Tutup
          </button>
          
          <button 
            onClick={handleWhatsApp}
            style={{ 
              width: '100%', 
              backgroundColor: '#E5E7EB', 
              color: 'var(--text-main)', 
              border: 'none', 
              padding: '16px', 
              borderRadius: '100px', 
              fontWeight: 600, 
              fontSize: 16, 
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 8
            }}
          >
            {/* Using MessageCircle to substitute the WA logo */}
            <MessageCircle size={20} />
            Hubungi Penjual
          </button>
        </div>
      </div>
    </div>
  );
}
