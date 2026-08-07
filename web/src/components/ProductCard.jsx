import React from 'react';
import ReactDOM from 'react-dom';

// formatter currency
const formatRp = (num) => {
  return 'Rp' + num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ".");
}

export default function ProductCard({ product, cartItem, onUpdateCart }) {
  const [showPreview, setShowPreview] = React.useState(false);
  const qty = cartItem ? cartItem.quantity : 0;
  const isSelected = qty > 0;

  const handleImageClick = (e) => {
    e.stopPropagation();
    setShowPreview(true);
  };

  const handlePlus = (e) => {
    e.stopPropagation();
    if (qty < product.stock) {
      onUpdateCart(product, qty + 1);
    }
  };

  const handleMinus = (e) => {
    e.stopPropagation();
    if (qty > 0) {
      onUpdateCart(product, qty - 1);
    }
  };

  const handleCardClick = () => {
    if (qty === 0 && product.stock > 0) {
      onUpdateCart(product, 1);
    }
  };

  return (
    <>
      <div 
        className={`product-card ${isSelected ? 'selected' : ''}`} 
        onClick={handleCardClick}
      >
        <img 
          onClick={handleImageClick}
          style={{ cursor: 'pointer' }} 
          src={product.image_url || 'https://via.placeholder.com/80'} 
          alt={product.name} 
          className="product-image" 
          onError={(e) => {
            e.target.onerror = null;
            e.target.src = 'https://via.placeholder.com/80?text=No+Image';
          }}
        />
        
        <div className="product-info">
          <div className="product-name">{product.name}</div>
          <div className="product-price-row">
            <span className="product-price">{formatRp(product.price)}</span>
            <span className="product-unit">/{product.unit}</span>
          </div>
          <div className="product-stock">Stok: {product.stock}</div>
        </div>

        {isSelected && (
          <div className="selected-actions">
            <div className="total-price-text">{formatRp(product.price * qty)}</div>
            
            <div className="qty-control">
              <button className="qty-btn minus" onClick={handleMinus}>-</button>
              <div className="qty-value">{qty}</div>
              <button className="qty-btn plus" onClick={handlePlus}>+</button>
            </div>
          </div>
        )}
      </div>

      {showPreview && ReactDOM.createPortal(
        <div 
          className="image-preview-overlay" 
          onClick={() => setShowPreview(false)}
        >
          <img 
            src={product.image_url || 'https://via.placeholder.com/80'} 
            alt={product.name} 
            onClick={(e) => e.stopPropagation()}
          />
          <div className="close-preview" onClick={() => setShowPreview(false)}>✕ Tutup</div>
        </div>,
        document.body
      )}
    </>
  );
}
