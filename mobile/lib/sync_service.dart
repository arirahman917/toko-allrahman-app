import 'dart:async';
import 'dart:io';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'auth_service.dart';
import 'models/category.dart';
import 'models/product.dart';
import 'models/transaction.dart';
import 'models/stock_adjustment.dart';
import 'models/order.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class SyncService {
  final Isar isar;
  final SupabaseClient supabase;
  Timer? _syncTimer;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  SyncService(this.isar, this.supabase) {
    _initNotifications();
  }

  void _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);
    
    // Request permission for Android 13+
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  void startPeriodicSync() {
    // Jalankan sync pertama kali
    syncData();
    // Lalu jalankan setiap 15 detik
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      syncData();
    });
  }

  void stopPeriodicSync() {
    _syncTimer?.cancel();
  }

  Future<void> syncData() async {
    try {
      final prefix = await AuthService.getCurrentUuidPrefix();
      
      // Cleanup bad UUIDs (with prefix) locally before sync
      await _cleanupBadUuids();

      await _syncCategories(prefix);
      await _syncProducts(prefix);
      await _syncTransactions(prefix);
      await _syncOnlineOrders();
    } catch (e) {
      print('Sync Error: $e');
    }
  }

  Future<void> _cleanupBadUuids() async {
    // Cari product yang id-nya mengandung '-' dan panjangnya > 36 (berarti ada prefix)
    final badProducts = await isar.products.filter().syncIdContains('-').findAll();
    for (var p in badProducts) {
      if (p.syncId.length > 36) {
        final parts = p.syncId.split('-');
        if (parts.length > 4) {
          // Asumsi prefix di depan, ambil UUID aslinya
          final realUuid = parts.skip(1).join('-');
          if (realUuid.length == 36) {
             await isar.writeTxn(() async {
               p.syncId = realUuid;
               await isar.products.put(p);
             });
          }
        }
      }
    }
    
    final badCats = await isar.categorys.filter().syncIdContains('-').findAll();
    for (var c in badCats) {
      if (c.syncId.length > 36) {
        final parts = c.syncId.split('-');
        if (parts.length > 4) {
          final realUuid = parts.skip(1).join('-');
          if (realUuid.length == 36) {
             await isar.writeTxn(() async {
               c.syncId = realUuid;
               await isar.categorys.put(c);
             });
          }
        }
      }
    }
  }

  Future<void> _syncCategories(String prefix) async {
    final unsynced = await isar.categorys.filter().isSyncedEqualTo(false).findAll();
    for (var cat in unsynced) {
      try {
        await supabase.from('categories').upsert({
          'id': cat.syncId,
          'name': cat.name,
          'created_at': cat.createdAt.toIso8601String(),
          'updated_at': cat.updatedAt.toIso8601String(),
          'deleted_at': cat.isDeleted ? DateTime.now().toIso8601String() : null,
          'created_by': prefix,
        });
        cat.isSynced = true;
        await isar.writeTxn(() async {
          await isar.categorys.put(cat);
        });
      } catch (e) {
        // Skip
      }
    }

    final remoteData = await supabase.from('categories').select();
    await isar.writeTxn(() async {
      for (var row in remoteData) {
        var existing = await isar.categorys.filter().syncIdEqualTo(row['id']).findFirst();
        if (existing == null) {
          existing = Category()
            ..syncId = row['id']
            ..name = row['name']
            ..createdAt = DateTime.parse(row['created_at'])
            ..updatedAt = DateTime.parse(row['updated_at'])
            ..isDeleted = row['deleted_at'] != null
            ..isSynced = true;
        } else {
          existing.name = row['name'];
          existing.updatedAt = DateTime.parse(row['updated_at']);
          existing.isDeleted = row['deleted_at'] != null;
          existing.isSynced = true;
        }
        await isar.categorys.put(existing);
      }
    });
  }

  Future<void> _syncProducts(String prefix) async {
    final unsynced = await isar.products.filter().isSyncedEqualTo(false).findAll();
    for (var prod in unsynced) {
      try {
        String? finalImageUrl = prod.imageUrl;
        // Jika imageUrl ada tapi bukan dari http (berarti file lokal)
        if (finalImageUrl != null && finalImageUrl.isNotEmpty && !finalImageUrl.startsWith('http')) {
          try {
            final file = File(finalImageUrl);
            if (await file.exists()) {
              final ext = finalImageUrl.split('.').last;
              final fileName = '${prod.syncId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
              
              await supabase.storage.from('product-images').upload(
                fileName, 
                file,
                fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
              );
              
              final publicUrl = supabase.storage.from('product-images').getPublicUrl(fileName);
              finalImageUrl = publicUrl;
              prod.imageUrl = publicUrl;
              
              await isar.writeTxn(() async {
                await isar.products.put(prod);
              });
            }
          } catch (e) {
            print('Gagal upload gambar: $e');
            // Tetap lanjut sync data meskipun gambar gagal
          }
        }

        await supabase.from('products').upsert({
          'id': prod.syncId,
          'category_id': prod.categoryId,
          'name': prod.name,
          'unit': prod.unit,
          'price': prod.price,
          'stock': prod.stock,
          'image_url': finalImageUrl,
          'barcode': prod.barcode,
          'created_at': prod.createdAt.toIso8601String(),
          'updated_at': prod.updatedAt.toIso8601String(),
          'deleted_at': prod.isDeleted ? DateTime.now().toIso8601String() : null,
          'created_by': prefix,
        });
        prod.isSynced = true;
        await isar.writeTxn(() async {
          await isar.products.put(prod);
        });
      } catch (e) {
        // Skip
      }
    }

    final remoteData = await supabase.from('products').select();
    await isar.writeTxn(() async {
      for (var row in remoteData) {
        var existing = await isar.products.filter().syncIdEqualTo(row['id']).findFirst();
        if (existing == null) {
          existing = Product()
            ..syncId = row['id']
            ..categoryId = row['category_id']
            ..name = row['name']
            ..unit = row['unit']
            ..price = double.parse(row['price'].toString())
            ..stock = row['stock']
            ..imageUrl = row['image_url']
            ..barcode = row['barcode']
            ..createdAt = DateTime.parse(row['created_at'])
            ..updatedAt = DateTime.parse(row['updated_at'])
            ..isDeleted = row['deleted_at'] != null
            ..isSynced = true;
        } else {
          existing.name = row['name'];
          existing.categoryId = row['category_id'];
          existing.unit = row['unit'];
          existing.price = double.parse(row['price'].toString());
          existing.stock = row['stock']; 
          existing.imageUrl = row['image_url'];
          existing.barcode = row['barcode'];
          existing.updatedAt = DateTime.parse(row['updated_at']);
          existing.isDeleted = row['deleted_at'] != null;
          existing.isSynced = true;
        }
        await isar.products.put(existing);
      }
    });
  }

  Future<void> _syncTransactions(String prefix) async {
    final unsyncedTx = await isar.posTransactions.filter().isSyncedEqualTo(false).findAll();
    for (var tx in unsyncedTx) {
      try {
        await supabase.from('transactions').upsert({
          'id': tx.syncId,
          'user_id': tx.userId,
          'customer_name': tx.customerName,
          'total_amount': tx.totalAmount,
          'paid_amount': tx.paidAmount,
          'change_amount': tx.changeAmount,
          'status': tx.status,
          'created_at': tx.createdAt.toIso8601String(),
          'created_by': prefix,
        });
        
        final items = await isar.posTransactionItems.filter().transactionSyncIdEqualTo(tx.syncId).findAll();
        for (var item in items) {
          await supabase.from('transaction_items').upsert({
            'id': item.syncId,
            'transaction_id': tx.syncId,
            'product_id': item.productSyncId,
            'quantity': item.quantity,
            'price_at_transaction': item.priceAtTransaction,
            'created_at': item.createdAt.toIso8601String(),
            'created_by': prefix,
          });
          item.isSynced = true;
          await isar.writeTxn(() async {
            await isar.posTransactionItems.put(item);
          });
        }
        
        tx.isSynced = true;
        await isar.writeTxn(() async {
          await isar.posTransactions.put(tx);
        });

        // Sync Payment Histories
        final payments = await isar.posPaymentHistorys.filter().transactionSyncIdEqualTo(tx.syncId).findAll();
        for (var payment in payments) {
          await supabase.from('payment_histories').upsert({
            'id': payment.syncId,
            'transaction_id': tx.syncId,
            'payment_amount': payment.paymentAmount,
            'debt_before_payment': payment.debtBeforePayment,
            'change_or_remaining_debt_after_payment': payment.changeOrRemainingDebtAfterPayment,
            'created_at': payment.createdAt.toIso8601String(),
            'created_by': prefix,
          });
          payment.isSynced = true;
          await isar.writeTxn(() async {
            await isar.posPaymentHistorys.put(payment);
          });
        }

      } catch (e) {
        // Skip
      }
    }
  }

  Future<void> _syncOnlineOrders() async {
    final remoteData = await supabase.from('orders').select().eq('status', 'pending');
    await isar.writeTxn(() async {
      for (var row in remoteData) {
        var existing = await isar.onlineOrders.filter().syncIdEqualTo(row['id']).findFirst();
        if (existing == null) {
          existing = OnlineOrder()
            ..syncId = row['id']
            ..customerName = row['customer_name']
            ..customerPhone = row['customer_phone']
            ..customerAddressText = row['customer_address_text']
            ..customerAddressLat = row['customer_address_lat'] != null ? double.parse(row['customer_address_lat'].toString()) : null
            ..customerAddressLng = row['customer_address_lng'] != null ? double.parse(row['customer_address_lng'].toString()) : null
            ..scheduledTime = row['scheduled_time'] != null ? DateTime.parse(row['scheduled_time']) : null
            ..totalAmount = double.parse(row['total_amount'].toString())
            ..status = row['status']
            ..createdAt = DateTime.parse(row['created_at'])
            ..isSynced = true;
          await isar.onlineOrders.put(existing);

          // Get Items
          final items = await supabase.from('order_items').select().eq('order_id', row['id']);
          for (var itemRow in items) {
            var exItem = await isar.onlineOrderItems.filter().syncIdEqualTo(itemRow['id']).findFirst();
            if (exItem == null) {
              exItem = OnlineOrderItem()
                ..syncId = itemRow['id']
                ..orderSyncId = itemRow['order_id']
                ..productSyncId = itemRow['product_id']
                ..quantity = itemRow['quantity']
                ..priceAtOrder = double.parse(itemRow['price_at_order'].toString())
                ..createdAt = DateTime.parse(itemRow['created_at'])
                ..isSynced = true;
              await isar.onlineOrderItems.put(exItem);
            }
          }
          
          // Trigger Notification for new order
          const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
            'new_orders_channel', 
            'Pesanan Baru',
            channelDescription: 'Notifikasi pesanan online baru',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker',
          );
          const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
          await flutterLocalNotificationsPlugin.show(
            id: 0,
            title: 'Pesanan Baru Masuk!',
            body: 'Dari: ${row['customer_name']}',
            notificationDetails: platformChannelSpecifics,
          );
        }
      }
    });
  }
}
