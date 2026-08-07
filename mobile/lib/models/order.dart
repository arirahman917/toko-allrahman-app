import 'package:isar/isar.dart';

part 'order.g.dart';

@collection
class OnlineOrder {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String syncId;

  late String customerName;
  String? customerPhone;
  String? customerAddressText;
  double? customerAddressLat;
  double? customerAddressLng;
  DateTime? scheduledTime;
  late double totalAmount;
  late String status;

  @Index()
  late DateTime createdAt;

  bool isSynced = false;
}

@collection
class OnlineOrderItem {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String syncId;

  @Index()
  late String orderSyncId;
  late String productSyncId;
  late int quantity;
  late double priceAtOrder;

  @Index()
  late DateTime createdAt;

  bool isSynced = false;
}
