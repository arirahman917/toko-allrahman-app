import 'package:isar/isar.dart';

part 'stock_adjustment.g.dart';

@collection
class StockAdjustment {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String syncId;

  late String productSyncId;
  late int adjustment;

  @Index()
  late DateTime createdAt;

  bool isSynced = false;
}
