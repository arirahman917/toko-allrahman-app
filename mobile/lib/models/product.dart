import 'package:isar/isar.dart';

part 'product.g.dart';

@collection
class Product {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String syncId;

  late String categoryId;
  late String name;
  late String unit;
  double? originalPrice;
  late double price;
  late int stock;
  String? imageUrl;
  String? barcode;

  @Index()
  late DateTime createdAt;
  late DateTime updatedAt;

  bool isSynced = false;
  bool isDeleted = false;
}
