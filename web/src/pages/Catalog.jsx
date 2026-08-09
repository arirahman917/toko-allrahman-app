import React, { useState, useEffect } from 'react';
import { supabase } from '../supabaseClient';


import Header from '../components/Header';
import ProductCard from '../components/ProductCard';
import BottomBar from '../components/BottomBar';
import IdentityModal from '../components/Modals/IdentityModal';
import CartModal from '../components/Modals/CartModal';
import SuccessModal from '../components/Modals/SuccessModal';

export default function Catalog() {
  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);

  const [search, setSearch] = useState('');
  const [sortDesc, setSortDesc] = useState(false);
  const [selectedCat, setSelectedCat] = useState('Semua');

  const [cart, setCart] = useState([]);
  const [identity, setIdentity] = useState(null);

  const [isIdentityOpen, setIsIdentityOpen] = useState(false);
  const [isCartOpen, setIsCartOpen] = useState(false);
  const [isSuccessOpen, setIsSuccessOpen] = useState(false);

  const [isSubmitting, setIsSubmitting] = useState(false);
  const [showIdentityWarning, setShowIdentityWarning] = useState(false);

  useEffect(() => {
    fetchCategories();
    fetchProducts();
  }, []);

  const fetchCategories = async () => {
    const { data } = await supabase.from('categories').select('*').is('deleted_at', null);
    if (data) setCategories(data);
  };

  const fetchProducts = async () => {
    const { data } = await supabase.from('products').select('*').is('deleted_at', null);
    if (data) setProducts(data);
  };

  const handleUpdateCart = (product, quantity) => {
    setCart(prev => {
      const existing = prev.find(item => item.product.id === product.id);
      if (quantity === 0) {
        return prev.filter(item => item.product.id !== product.id);
      }
      if (existing) {
        return prev.map(item => item.product.id === product.id ? { ...item, quantity } : item);
      }
      return [...prev, { product, quantity }];
    });
  };

  const handleRemoveFromCart = (productId) => {
    setCart(prev => prev.filter(item => item.product.id !== productId));
  };

  const handleSubmitOrder = async () => {
    if (!identity) {
      setShowIdentityWarning(true);
      return;
    }
    if (cart.length === 0) return;

    setIsSubmitting(true);

    // Generate UUID via crypto (supported in modern browsers)
    const orderId = crypto.randomUUID();
    const totalAmount = cart.reduce((acc, item) => acc + (item.product.price * item.quantity), 0);

    try {
      // 1. Insert into orders table
      const { error: orderError } = await supabase.from('orders').insert({
        id: orderId,
        customer_name: identity.name,
        customer_phone: identity.whatsapp,
        customer_address_text: identity.address,
        // Asumsi format location adalah "lat, lng" dari IdentityModal
        customer_address_lat: identity.location ? parseFloat(identity.location.split(',')[0]) : null,
        customer_address_lng: identity.location ? parseFloat(identity.location.split(',')[1]) : null,
        scheduled_time: identity.orderDate ? identity.orderDate : null,
        total_amount: totalAmount,
        status: 'pending',
        created_at: new Date().toISOString(),
      });

      if (orderError) throw orderError;

      // 2. Insert items into order_items
      const orderItems = cart.map(item => ({
        id: crypto.randomUUID(),
        order_id: orderId,
        product_id: item.product.id,
        quantity: item.quantity,
        price_at_order: item.product.price,
        created_at: new Date().toISOString(),
      }));

      const { error: itemsError } = await supabase.from('order_items').insert(orderItems);

      if (itemsError) throw itemsError;

      // Success
      setCart([]);
      setIsCartOpen(false);
      setIsSuccessOpen(true);

    } catch (error) {
      console.error("Error submitting order:", error);
      alert("Terjadi kesalahan saat membuat pesanan: " + error.message);
    } finally {
      setIsSubmitting(false);
    }
  };

  // Derived state for filtering
  let filteredProducts = products.filter(p => {
    const matchSearch = p.name.toLowerCase().includes(search.toLowerCase());
    const matchCat = selectedCat === 'Semua' || p.category_id === selectedCat;
    return matchSearch && matchCat;
  });

  if (sortDesc) {
    filteredProducts.sort((a, b) => b.name.localeCompare(a.name));
  } else {
    filteredProducts.sort((a, b) => a.name.localeCompare(b.name));
  }

  return (
    <div className="container">
      <Header
        search={search}
        setSearch={setSearch}
        sortDesc={sortDesc}
        setSortDesc={setSortDesc}
        categories={categories}
        selectedCat={selectedCat}
        setSelectedCat={setSelectedCat}
        totalItems={filteredProducts.length}
      />

      <div className="product-list-container">
        {filteredProducts.map(product => (
          <ProductCard
            key={product.id}
            product={product}
            cartItem={cart.find(item => item.product.id === product.id)}
            onUpdateCart={handleUpdateCart}
          />
        ))}
        {filteredProducts.length === 0 && (
          <div style={{ textAlign: 'center', marginTop: 40, color: '#6B7280' }}>
            Barang tidak ditemukan
          </div>
        )}
      </div>

      <BottomBar
        cart={cart}
        hasIdentity={!!identity}
        onOpenIdentity={() => setIsIdentityOpen(true)}
        onOpenCart={() => setIsCartOpen(true)}
        onSubmit={handleSubmitOrder}
      />

      <IdentityModal
        isOpen={isIdentityOpen}
        onClose={() => setIsIdentityOpen(false)}
        identity={identity}
        onSave={(data) => {
          setIdentity(data);
        }}
      />

      <CartModal
        isOpen={isCartOpen}
        onClose={() => setIsCartOpen(false)}
        cart={cart}
        onRemoveItem={handleRemoveFromCart}
      />

      <SuccessModal
        isOpen={isSuccessOpen}
        onClose={() => setIsSuccessOpen(false)}
      />

      {showIdentityWarning && (
        <div className="modal-overlay" style={{ zIndex: 999, justifyContent: 'center', alignItems: 'center' }}>
          <div style={{
            background: 'white', padding: 28, borderRadius: 20,
            textAlign: 'center', maxWidth: 320, width: '90%',
            animation: 'zoomIn 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275) forwards'
          }}>
            <div style={{ fontSize: 48, marginBottom: 12 }}>👋</div>
            <div style={{ fontWeight: 700, fontSize: 18, marginBottom: 8 }}>Halo, Pak/Bu!</div>
            <div style={{ color: '#6B7280', fontSize: 14, marginBottom: 24, lineHeight: 1.5 }}>
              Sebelum pesan, isi identitas dulu yaa biar kami bisa menghubungi dan mengantar pesanannya 😊
            </div>
            <button
              onClick={() => { setShowIdentityWarning(false); setIsIdentityOpen(true); }}
              style={{
                width: '100%', padding: 14, background: '#0A55D9', color: 'white',
                border: 'none', borderRadius: 100, fontWeight: 600, fontSize: 15,
                cursor: 'pointer', marginBottom: 8
              }}
            >
              Isi Identitas
            </button>
            <button
              onClick={() => setShowIdentityWarning(false)}
              style={{
                width: '100%', padding: 12, background: '#F3F4F6', color: '#6B7280',
                border: 'none', borderRadius: 100, fontWeight: 500, fontSize: 14,
                cursor: 'pointer'
              }}
            >
              Nanti dulu
            </button>
          </div>
        </div>
      )}

      {isSubmitting && (
        <div className="modal-overlay" style={{ zIndex: 999, justifyContent: 'center', alignItems: 'center' }}>
          <div style={{ background: 'white', padding: 24, borderRadius: 12 }}>
            Memproses Pesanan...
          </div>
        </div>
      )}
    </div>
  );
}
