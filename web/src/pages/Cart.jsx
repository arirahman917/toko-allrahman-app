import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../supabaseClient';
import { ArrowLeft, Trash2, MapPin, Phone, User, Clock } from 'lucide-react';

export default function Cart({ cart, setCart, identity }) {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(false);

  const totalAmount = cart.reduce((sum, item) => sum + (item.price * item.quantity), 0);

  const handleRemove = (id) => {
    if (window.confirm("Apakah yakin barang ini dihapus?")) {
      setCart(cart.filter(item => item.id !== id));
    }
  };

  const handleCheckout = async () => {
    if (cart.length === 0) {
      alert("Keranjang belanja kosong.");
      return;
    }
    if (!identity) {
      alert("Silahkan isi identitas & alamat pengiriman terlebih dahulu.");
      navigate('/identity');
      return;
    }

    setLoading(true);
    try {
      // Create Order
      const { data: orderData, error: orderError } = await supabase.from('orders').insert([{
        customer_name: identity.name,
        customer_phone: identity.phone,
        customer_address_text: identity.address,
        customer_address_lat: identity.lat,
        customer_address_lng: identity.lng,
        scheduled_time: identity.scheduledTime,
        total_amount: totalAmount,
        status: 'pending'
      }]).select().single();

      if (orderError) throw orderError;

      // Insert order items
      const orderItems = cart.map(item => ({
        order_id: orderData.id,
        product_id: item.id,
        quantity: item.quantity,
        price_at_order: item.price
      }));

      const { error: itemsError } = await supabase.from('order_items').insert(orderItems);
      if (itemsError) throw itemsError;

      setCart([]);
      
      alert("Pemesanan berhasil! Toko All Rahman akan segera memprosesnya.");
      if (window.confirm("Ingin konfirmasi pesanan ke penjual via WhatsApp?")) {
        window.location.href = `https://wa.me/6285794372178?text=Halo,%20saya%20${identity.name}%20baru%20saja%20membuat%20pesanan%20via%20website%20dengan%20total%20Rp%20${totalAmount.toLocaleString('id-ID')}.`;
      } else {
        navigate('/');
      }

    } catch (error) {
      console.error(error);
      alert("Terjadi kesalahan saat memproses pesanan: " + error.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <div className="glass-header" style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
        <button 
          onClick={() => navigate(-1)} 
          style={{ background: 'none', border: 'none', cursor: 'pointer', padding: '8px', marginLeft: '-8px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}
        >
          <ArrowLeft size={24} color="var(--color-black)" />
        </button>
        <h2 style={{ margin: 0, fontSize: '20px', fontWeight: '700' }}>Keranjang Belanja</h2>
      </div>

      <div style={{ padding: '24px 16px' }}>
        {cart.length === 0 ? (
          <div style={{ textAlign: 'center', padding: '60px 20px', color: 'var(--color-gray-dark)' }}>
            <div style={{ width: '80px', height: '80px', borderRadius: '50%', backgroundColor: 'var(--color-gray-light)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 16px' }}>
              <Trash2 size={32} color="var(--color-gray-dark)" opacity={0.5} />
            </div>
            <h3 style={{ margin: '0 0 8px', color: 'var(--color-black)' }}>Keranjang Masih Kosong</h3>
            <p style={{ margin: 0, fontSize: '14px' }}>Silakan pilih barang dari katalog kami.</p>
            <button className="btn btn-primary" onClick={() => navigate('/')} style={{ marginTop: '24px' }}>Mulai Belanja</button>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <div className="glass-card" style={{ padding: '16px', display: 'flex', flexDirection: 'column', gap: '12px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <h3 style={{ margin: 0, fontSize: '16px' }}>Informasi Pengiriman</h3>
                <button 
                  onClick={() => navigate('/identity')}
                  style={{ background: 'none', border: 'none', color: 'var(--color-primary)', fontWeight: '600', cursor: 'pointer', fontSize: '14px' }}
                >
                  {identity ? 'Ubah' : 'Isi Sekarang'}
                </button>
              </div>
              
              {identity ? (
                <div style={{ backgroundColor: 'var(--color-gray-light)', padding: '12px', borderRadius: '8px', fontSize: '14px', display: 'flex', flexDirection: 'column', gap: '8px' }}>
                  <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}><User size={16} /> <strong>{identity.name}</strong></div>
                  <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}><Phone size={16} /> {identity.phone}</div>
                  <div style={{ display: 'flex', gap: '8px', alignItems: 'flex-start' }}><MapPin size={16} style={{ marginTop: '2px' }}/> <span>{identity.address}</span></div>
                  {identity.scheduledTime && (
                    <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}><Clock size={16} /> Kirim: {new Date(identity.scheduledTime).toLocaleString('id-ID')}</div>
                  )}
                </div>
              ) : (
                <div style={{ backgroundColor: '#fffbeb', color: '#d97706', padding: '12px', borderRadius: '8px', fontSize: '14px', border: '1px solid #fde68a' }}>
                  ⚠️ Anda belum mengisi identitas dan alamat pengiriman.
                </div>
              )}
            </div>

            <h3 style={{ margin: '8px 0 0', fontSize: '16px' }}>Daftar Pesanan ({cart.length})</h3>
            
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              {cart.map(item => (
                <div key={item.id} className="glass-card" style={{ display: 'flex', padding: '12px', gap: '12px' }}>
                  <div style={{ width: '60px', height: '60px', backgroundColor: 'var(--color-gray-light)', borderRadius: '8px', backgroundImage: item.image_url ? `url(${item.image_url})` : 'none', backgroundSize: 'cover', backgroundPosition: 'center' }}></div>
                  <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
                    <h4 style={{ margin: '0 0 4px 0', fontSize: '14px' }}>{item.name}</h4>
                    <div style={{ color: 'var(--color-gray-dark)', fontSize: '12px' }}>
                      {item.quantity} x Rp {item.price.toLocaleString('id-ID')}
                    </div>
                    <div style={{ fontWeight: '700', color: 'var(--color-primary)', marginTop: '4px' }}>
                      Rp {(item.quantity * item.price).toLocaleString('id-ID')}
                    </div>
                  </div>
                  <button 
                    onClick={() => handleRemove(item.id)}
                    style={{ background: 'none', border: 'none', color: 'var(--color-red)', cursor: 'pointer', padding: '8px', alignSelf: 'center' }}
                  >
                    <Trash2 size={20} />
                  </button>
                </div>
              ))}
            </div>

            <div className="glass-card" style={{ marginTop: '8px', padding: '16px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', backgroundColor: 'white' }}>
              <span style={{ fontWeight: '600', color: 'var(--color-gray-dark)' }}>Total Pembayaran</span>
              <span style={{ fontSize: '20px', fontWeight: '800', color: 'var(--color-black)' }}>
                Rp {totalAmount.toLocaleString('id-ID')}
              </span>
            </div>

            <button 
              onClick={handleCheckout} 
              disabled={loading || cart.length === 0}
              className="btn btn-primary" 
              style={{ width: '100%', marginTop: '8px', padding: '16px', fontSize: '16px', opacity: (loading || cart.length === 0) ? 0.7 : 1 }}
            >
              {loading ? 'Memproses Pesanan...' : 'Pesan Sekarang'}
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
