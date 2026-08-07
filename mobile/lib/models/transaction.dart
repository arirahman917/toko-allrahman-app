import 'package:isar/isar.dart';

part 'transaction.g.dart';

@collection
class PosTransaction {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String syncId;

  late String userId;
  String customerName = 'Fulan';
  String? customerAddress;
  String? customerLocationUrl;
  late double totalAmount;
  late double paidAmount;
  late double changeAmount;
  late String status; // lunas, hutang

  @Index()
  late DateTime createdAt;
  late DateTime updatedAt;

  bool isSynced = false;
  bool isDeleted = false;
}

@collection
class PosTransactionItem {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String syncId;

  @Index()
  late String transactionSyncId;
  late String productSyncId;
  late int quantity;
  late double priceAtTransaction;

  @Index()
  late DateTime createdAt;
  
  bool isSynced = false;
}

@collection
class PosPaymentHistory {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String syncId;

  @Index()
  late String transactionSyncId;
  
  late double paymentAmount;
  late double debtBeforePayment;
  late double changeOrRemainingDebtAfterPayment;
  
  @Index()
  late DateTime createdAt;

  bool isSynced = false;
}
