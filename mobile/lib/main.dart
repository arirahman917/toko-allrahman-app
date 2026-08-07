import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/category.dart';
import 'models/product.dart';
import 'models/transaction.dart';
import 'models/stock_adjustment.dart';
import 'models/order.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'sync_service.dart';

import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  
  // 1. Inisialisasi Isar (Offline DB)
  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    [
      CategorySchema, 
      ProductSchema, 
      PosTransactionSchema, 
      PosTransactionItemSchema,
      PosPaymentHistorySchema,
      StockAdjustmentSchema,
      OnlineOrderSchema,
      OnlineOrderItemSchema
    ],
    directory: dir.path,
  );

  // 2. Inisialisasi Supabase (Online DB) - NON-BLOCKING
  // Jangan await agar tidak menyebabkan black screen saat tidak ada internet
  try {
    await Supabase.initialize(
      url: 'https://jvpnuzlyaxhkzrxasvbx.supabase.co',
      anonKey: 'sb_publishable_fdFMKXVBx4iD231gdgLmNg_Sn-uwahg',
    ).timeout(const Duration(seconds: 5), onTimeout: () {
      debugPrint('Supabase init timeout, continuing offline...');
      return Supabase.instance;
    });
  } catch (e) {
    debugPrint('Supabase init error: $e, continuing offline...');
  }

  // 3. Sync Service
  SyncService? syncService;
  try {
    syncService = SyncService(isar, Supabase.instance.client);
    syncService.startPeriodicSync();
  } catch (e) {
    debugPrint('Sync service init error: $e');
  }
  
  runApp(
    MultiProvider(
      providers: [
        Provider<Isar>.value(value: isar),
        if (syncService != null)
          Provider<SyncService>.value(value: syncService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Toko All Rahman',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF004ECD)),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      home: const SplashScreen(),
    );
  }
}
