import { createClient } from '@supabase/supabase-js'

// Menggunakan variable env. Jika belum ada, menggunakan placeholder sementara.
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || 'https://jvpnuzlyaxhkzrxasvbx.supabase.co'
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || 'sb_publishable_fdFMKXVBx4iD231gdgLmNg_Sn-uwahg'

export const supabase = createClient(supabaseUrl, supabaseAnonKey)
