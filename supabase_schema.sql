-- supabase_schema.sql

-- Kategori Barang
CREATE TABLE categories (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  deleted_at TIMESTAMP WITH TIME ZONE
);

-- Produk Barang
CREATE TABLE products (
  id UUID PRIMARY KEY,
  category_id UUID REFERENCES categories(id),
  name TEXT NOT NULL,
  unit TEXT NOT NULL,
  price NUMERIC NOT NULL,
  stock INTEGER NOT NULL DEFAULT 0,
  image_url TEXT,
  barcode TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  deleted_at TIMESTAMP WITH TIME ZONE
);

-- Penyesuaian Stok (Event Sourcing)
CREATE TABLE stock_adjustments (
  id UUID PRIMARY KEY,
  product_id UUID REFERENCES products(id),
  adjustment INTEGER NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Transaksi (Kasir)
CREATE TABLE transactions (
  id UUID PRIMARY KEY,
  user_id TEXT NOT NULL,
  customer_name TEXT DEFAULT 'Fulan',
  total_amount NUMERIC NOT NULL,
  paid_amount NUMERIC NOT NULL,
  change_amount NUMERIC NOT NULL,
  status TEXT NOT NULL, -- 'lunas', 'hutang'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  deleted_at TIMESTAMP WITH TIME ZONE
);

-- Item Transaksi
CREATE TABLE transaction_items (
  id UUID PRIMARY KEY,
  transaction_id UUID REFERENCES transactions(id),
  product_id UUID REFERENCES products(id),
  quantity INTEGER NOT NULL,
  price_at_transaction NUMERIC NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Pesanan Online (Website)
CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_name TEXT NOT NULL,
  customer_phone TEXT,
  customer_address_text TEXT,
  customer_address_lat NUMERIC,
  customer_address_lng NUMERIC,
  scheduled_time TIMESTAMP WITH TIME ZONE,
  total_amount NUMERIC NOT NULL,
  status TEXT DEFAULT 'pending', -- 'pending', 'completed'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Item Pesanan Online
CREATE TABLE order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID REFERENCES orders(id),
  product_id UUID REFERENCES products(id),
  quantity INTEGER NOT NULL,
  price_at_order NUMERIC NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Trigger: Kurangi stok saat ada transaksi
CREATE OR REPLACE FUNCTION decrement_stock_on_transaction()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE products
  SET stock = stock - NEW.quantity
  WHERE id = NEW.product_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_decrement_stock
AFTER INSERT ON transaction_items
FOR EACH ROW
EXECUTE FUNCTION decrement_stock_on_transaction();

-- Trigger: Tambah/Kurangi stok saat ada restock (adjustment manual)
CREATE OR REPLACE FUNCTION apply_stock_adjustment()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE products
  SET stock = stock + NEW.adjustment
  WHERE id = NEW.product_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_apply_stock_adjustment
AFTER INSERT ON stock_adjustments
FOR EACH ROW
EXECUTE FUNCTION apply_stock_adjustment();

-- Storage: product-images bucket
-- Insert bucket jika belum ada
INSERT INTO storage.buckets (id, name, public) 
VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) DO NOTHING;

-- Policy agar semua orang bisa baca gambar (Web)
CREATE POLICY "Public Access" 
ON storage.objects FOR SELECT 
USING (bucket_id = 'product-images');

-- Policy agar aplikasi bisa upload gambar (Anon / Authenticated)
CREATE POLICY "Insert Access" 
ON storage.objects FOR INSERT 
WITH CHECK (bucket_id = 'product-images');

