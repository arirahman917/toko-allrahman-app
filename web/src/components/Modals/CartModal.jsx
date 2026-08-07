import React from 'react';
import { X, Trash2 } from 'lucide-react';

const formatRp = (num) => {
  return 'Rp' + num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".");
}

export default function CartModal({ isOpen, onClose, cart, onRemoveItem }) {
  if (!isOpen) return null;

  const total = cart.reduce((acc, item) => acc + (item.product.price * item.quantity), 0);

  return (
    <div className="modal-overlay">
      <div className="modal-content centered">
        <div className="modal-header">
          <div style={{ width: 24 }}></div>
          <h2 className="modal-title">Keranjang</h2>
          <button className="close-btn" onClick={onClose}><X size={24} /></button>
        </div>

        {cart.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '40px 0', color: 'var(--text-muted)' }}>
            Keranjang Anda kosong.
          </div>
        ) : (
          <div className="cart-list">
            {cart.map((item) => (
              <div key={item.product.id} className="cart-item">
                <img 
                  src={item.product.image_url || 'https://via.placeholder.com/60'} 
                  alt={item.product.name} 
                  className="cart-item-image" 
                  onError={(e) => {
                    e.target.onerror = null;
                    e.target.src = 'https://via.placeholder.com/60?text=No+Image';
                  }}
                />
                
                <div className="cart-item-details">
                  <div className="cart-item-title">{item.product.name}</div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 8 }}>
                    <div className="cart-item-qty">{item.quantity}</div>
                    <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>
                      × {formatRp(item.product.price)} /{item.product.unit}
                    </div>
                  </div>
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 12 }}>
                  <div className="cart-item-price">{formatRp(item.product.price * item.quantity)}</div>
                  <button className="btn-delete" onClick={() => onRemoveItem(item.product.id)}>
                    <Trash2 size={20} />
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}

        <div className="cart-total-box">
          <div className="cart-total-label">Total</div>
          <div className="cart-total-value">{formatRp(total)}</div>
        </div>
      </div>
    </div>
  );
}
