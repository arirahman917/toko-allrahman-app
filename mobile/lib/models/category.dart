import 'package:isar/isar.dart';

part 'category.g.dart';

@collection
class Category {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String syncId;

  late String name;

  @Index()
  late DateTime createdAt;
  late DateTime updatedAt;

  bool isSynced = false;
  bool isDeleted = false;
}
