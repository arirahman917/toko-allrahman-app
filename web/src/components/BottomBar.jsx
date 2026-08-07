import React from 'react';
import { User, ShoppingCart } from 'lucide-react';

const formatRp = (num) => {
  return 'Rp' + num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".");
}

export default function BottomBar({ cart, onOpenIdentity, onOpenCart, onSubmit, hasIdentity }) {
  const totalItems = cart.reduce((acc, item) => acc + item.quantity, 0);
  const totalPrice = cart.reduce((acc, item) => acc + (item.product.price * item.quantity), 0);

  const isCartEmpty = totalItems === 0;

  return (
    <div className="bottom-bar">
      <div className="bottom-stats-row">
        <button className="bottom-icon-btn" onClick={onOpenIdentity}>
          <div style={{ position: 'relative' }}>
            <User size={24} />
            {hasIdentity && (
              <div style={{ 
                position: 'absolute', top: -4, right: -4, 
                backgroundColor: '#10B981', color: 'white',
                borderRadius: '50%', width: 14, height: 14,
                display: 'flex', alignItems: 'center', justifyContent: 'center'
              }}>
                <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="4" strokeLinecap="round" strokeLinejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>
              </div>
            )}
          </div>
          <span>Identitas</span>
        </button>

        <div className="total-display">
          <div className={`total-amount ${!isCartEmpty ? 'active' : ''}`}>
            {isCartEmpty ? 'Rp -' : formatRp(totalPrice)}
          </div>
        </div>

        <button className="bottom-icon-btn" onClick={onOpenCart}>
          <ShoppingCart size={24} />
          <span>Keranjang</span>
          {!isCartEmpty && <div className="cart-badge">{totalItems}</div>}
        </button>
      </div>

      <button 
        className="btn-pesan" 
        disabled={isCartEmpty || !hasIdentity}
        onClick={onSubmit}
      >
        Pesan
      </button>
    </div>
  );
}
