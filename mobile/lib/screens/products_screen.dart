import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:isar/isar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../models/product.dart';
import '../models/category.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../uuid_helper.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

enum SortOption { az, za, stockLowHigh, stockHighLow }

class _ProductsScreenState extends State<ProductsScreen> {
  SortOption _currentSort = SortOption.az;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
  String _searchQuery = '';
  String? _selectedCategoryId;

  Widget _buildProductImage(String url, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    if (url.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Container(
          width: width, height: height, 
          color: Colors.grey.shade200, 
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2))
        ),
        errorWidget: (context, url, error) => Container(
          width: width, height: height, 
          color: Colors.grey.shade200, 
          child: const Icon(Icons.error, color: Colors.grey)
        ),
      );
    } else {
      return Image.file(
        File(url),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => Container(
          width: width, height: height, 
          color: Colors.grey.shade200, 
          child: const Icon(Icons.broken_image, color: Colors.grey)
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isar = Provider.of<Isar>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header (Logo & Name)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  const Icon(Icons.shopping_bag, color: Color(0xFF0D47A1), size: 36),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AL RAHMAN',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0D47A1),
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        '— TOKO GROSIR SEMBAKO —',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade300,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Title & Add Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StreamBuilder<int>(
                    stream: isar.products.where().watch(fireImmediately: true).map((list) => list.where((p) => !p.isDeleted).length),
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return RichText(
                        text: TextSpan(
                          text: 'Barang ',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                          children: [
                            TextSpan(
                              text: '($count Item)',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showProductForm(context, isar),
                    icon: const Icon(Icons.add, size: 18, color: Colors.white),
                    label: const Text('Tambah', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1), // Blue
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),

            // Search bar & Filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        onChanged: (value) => setState(() => _searchQuery = value),
                        decoration: const InputDecoration(
                          hintText: 'Cari...',
                          prefixIcon: Icon(Icons.search, color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: PopupMenuButton<SortOption>(
              icon: const Icon(Icons.tune, color: Color(0xFF0D47A1)),
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              offset: const Offset(0, 40),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _currentSort == SortOption.az ? SortOption.za : SortOption.az,
                  child: Row(
                    children: [
                      Icon(_currentSort == SortOption.az ? Icons.sort_by_alpha : Icons.sort_by_alpha, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(_currentSort == SortOption.az ? 'A-Z' : 'Z-A'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _currentSort == SortOption.stockLowHigh ? SortOption.stockHighLow : SortOption.stockLowHigh,
                  child: Row(
                    children: [
                      Icon(_currentSort == SortOption.stockLowHigh ? Icons.inventory_2_outlined : Icons.inventory_2, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(_currentSort == SortOption.stockLowHigh ? 'Stok: Sedikit ke Banyak' : 'Stok: Banyak ke Sedikit'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                setState(() {
                  _currentSort = value;
                });
              },
            ),
                  ),
                ],
              ),
            ),

            // Category filter chips
            SizedBox(
              height: 50,
              child: StreamBuilder<List<Category>>(
                stream: isar.categorys.where().watch(fireImmediately: true),
                builder: (context, snapshot) {
                  final categories = snapshot.data ?? [];
                  return ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    children: [
                      _buildCategoryChip('Semua', null),
                      ...categories.map((cat) => _buildCategoryChip(cat.name, cat.syncId)),
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: ActionChip(
                          label: const Icon(Icons.add, size: 20),
                          onPressed: () async {
                            final catNameCtrl = TextEditingController();
                            final newCatName = await showDialog<String>(
                              context: context,
                              builder: (dCtx) => AlertDialog(
                                title: const Text('Kategori Baru'),
                                content: TextField(controller: catNameCtrl, decoration: const InputDecoration(hintText: 'Nama Kategori')),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Batal')),
                                  TextButton(onPressed: () => Navigator.pop(dCtx, catNameCtrl.text.trim()), child: const Text('Simpan')),
                                ],
                              ),
                            );
                            if (newCatName != null && newCatName.isNotEmpty) {
                              final newCat = Category()..syncId = await UuidHelper.generatePrefixed()..name = newCatName..createdAt = DateTime.now()..updatedAt = DateTime.now();
                              await isar.writeTxn(() async => await isar.categorys.put(newCat));
                            }
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // Product list
            Expanded(
              child: StreamBuilder<List<Product>>(
                stream: isar.products.where().watch(fireImmediately: true),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var products = snapshot.data!.where((p) => !p.isDeleted).toList();

                  if (_searchQuery.isNotEmpty) {
                    products = products.where((p) =>
                      p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      (p.barcode?.contains(_searchQuery) ?? false)
                    ).toList();
                  }

                  if (_selectedCategoryId != null) {
                    products = products.where((p) => p.categoryId == _selectedCategoryId).toList();
                  }

                  if (_currentSort == SortOption.az) {
                   products.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                 } else if (_currentSort == SortOption.za) {
                   products.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
                 } else if (_currentSort == SortOption.stockLowHigh) {
                   products.sort((a, b) => a.stock.compareTo(b.stock));
                 } else if (_currentSort == SortOption.stockHighLow) {
                   products.sort((a, b) => b.stock.compareTo(a.stock));
                 }

                 if (products.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.isNotEmpty ? 'Tidak ditemukan' : 'Belum ada barang',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80), // Padding bottom for nav bar
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      
                      // Stock Badge Logic
                      Color cardColor = Colors.white;
                      Color badgeBgColor = Colors.blue.shade50;
                      Color badgeTextColor = const Color(0xFF0D47A1);
                      
                      if (product.stock == 0) {
                        cardColor = const Color(0xFFFFEBEE); // Light red/pink
                        badgeBgColor = const Color(0xFFEF9A9A);
                        badgeTextColor = const Color(0xFFC62828); // Dark red
                      } else if (product.stock <= 3) {
                        cardColor = Colors.white;
                        badgeBgColor = const Color(0xFFFFF9C4); // Light yellow
                        badgeTextColor = const Color(0xFFF57F17); // Dark yellow/orange
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Image
                              GestureDetector(
                               onTap: () {
                                 if (product.imageUrl != null) {
                                   showDialog(
                                     context: context,
                                     builder: (previewCtx) => Dialog(
                                       backgroundColor: Colors.transparent,
                                       insetPadding: const EdgeInsets.all(32),
                                       child: Column(
                                         mainAxisSize: MainAxisSize.min,
                                         children: [
                                           ClipRRect(
                                             borderRadius: BorderRadius.circular(16),
                                             child: AspectRatio(
                                               aspectRatio: 1,
                                               child: _buildProductImage(product.imageUrl!),
                                             ),
                                           ),
                                           const SizedBox(height: 16),
                                           ElevatedButton.icon(
                                             onPressed: () => Navigator.pop(previewCtx),
                                             icon: const Icon(Icons.close, size: 18),
                                             label: const Text('Tutup'),
                                             style: ElevatedButton.styleFrom(
                                               backgroundColor: Colors.white,
                                               foregroundColor: Colors.black87,
                                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                             ),
                                           ),
                                         ],
                                       ),
                                     ),
                                   );
                                 }
                               },
                               child: ClipRRect(
                                 borderRadius: BorderRadius.circular(8),
                                 child: product.imageUrl != null
                                   ? _buildProductImage(product.imageUrl!, width: 70, height: 70)
                                   : Container(width: 70, height: 70, color: Colors.grey.shade200, child: const Icon(Icons.inventory_2, color: Colors.grey)),
                               ),
                             ),
                              const SizedBox(width: 12),
                              
                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    RichText(
                                      text: TextSpan(
                                        text: _currencyFormat.format(product.price),
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 14),
                                        children: [
                                          TextSpan(
                                            text: ' /${product.unit}',
                                            style: const TextStyle(fontWeight: FontWeight.normal, color: Colors.grey, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Badge & Menu
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: badgeBgColor,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Stok: ${product.stock}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: badgeTextColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: () {
                                      _showProductMenu(context, isar, product);
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(4.0),
                                      child: Icon(Icons.more_horiz, color: Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, String? categoryId) {
    final isSelected = _selectedCategoryId == categoryId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedCategoryId = categoryId),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE3F2FD) : Colors.white, // Light blue if selected
            border: Border.all(color: isSelected ? const Color(0xFF0D47A1) : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF0D47A1) : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  void _showProductMenu(BuildContext context, Isar isar, Product product) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.blue),
              title: const Text('Edit Barang'),
              onTap: () {
                Navigator.pop(context);
                _showProductForm(context, isar, product: product);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Hapus', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteProduct(context, isar, product);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showProductForm(BuildContext context, Isar isar, {Product? product}) async {
    final outerContext = context;
    final isEdit = product != null;
    final nameController = TextEditingController(text: product?.name ?? '');
    final originalPriceController = TextEditingController(text: product?.originalPrice?.toStringAsFixed(0) ?? '');
    final priceController = TextEditingController(text: product?.price.toStringAsFixed(0) ?? '');
    final stockController = TextEditingController(text: product?.stock.toString() ?? '');
    final barcodeController = TextEditingController(text: product?.barcode ?? '');

    String? selectedCategoryId = product?.categoryId;
    String? selectedCategoryName;
    String? selectedUnit = product?.unit;
    String? localImagePath = product?.imageUrl;

    bool hasBarcode = product?.barcode != null && product!.barcode!.isNotEmpty;
    if (!isEdit) hasBarcode = true;

    final List<String> availableUnits = ['pcs', 'kg', 'gram', 'liter', 'dus', 'pak', 'renceng'];
    if (selectedUnit != null && !availableUnits.contains(selectedUnit)) availableUnits.add(selectedUnit!);

    // Load category name for edit mode
    if (selectedCategoryId != null) {
      final cats = await isar.categorys.where().findAll();
      for (final c in cats) {
        if (c.syncId == selectedCategoryId) {
          selectedCategoryName = c.name;
          break;
        }
      }
    }

    // Validation error states
    String? nameError;
    String? categoryError;
    String? unitError;
    String? priceError;
    String? stockError;

    if (!outerContext.mounted) return;

    showDialog(
      context: outerContext,
      barrierDismissible: false,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: const EdgeInsets.all(20.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 24),
                          Expanded(
                            child: Text(
                              isEdit ? 'Edit Barang' : 'Tambah Barang',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ),
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(Icons.close, color: Colors.black87),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Row 1: Nama Barang
                      Row(
                        children: [
                          const Icon(Icons.edit_outlined, size: 28, color: Colors.black87),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: nameController,
                              onChanged: (_) { if (nameError != null) setModalState(() => nameError = null); },
                              decoration: InputDecoration(
                                labelText: 'Nama barang',
                                floatingLabelBehavior: FloatingLabelBehavior.auto,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                errorText: nameError,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Row 2: Kategori (full width)
                      Row(
                        children: [
                          const Icon(Icons.folder_outlined, size: 28, color: Colors.black87),
                          const SizedBox(width: 16),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                                  builder: (ctx) => StatefulBuilder(
                                    builder: (ctx, setBottomSheetState) => SafeArea(
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.55),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                                            const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Pilih Kategori', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                            Flexible(
                                              child: StreamBuilder<List<Category>>(
                                                stream: isar.categorys.where().watch(fireImmediately: true),
                                                builder: (context, snapshot) {
                                                  final categories = snapshot.data ?? [];
                                                  return ListView(
                                                    shrinkWrap: true,
                                                    children: [
                                                      ...categories.map((c) => ListTile(
                                                        title: Text(c.name),
                                                        trailing: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            if (c.syncId == selectedCategoryId) const Icon(Icons.check_circle, color: Colors.blue, size: 20),
                                                            const SizedBox(width: 8),
                                                            GestureDetector(
                                                              onTap: () async {
                                                                final confirm = await showDialog<bool>(
                                                                  context: ctx,
                                                                  builder: (dCtx) => AlertDialog(
                                                                    title: const Text('Hapus Kategori?'),
                                                                    content: Text('Hapus kategori "${c.name}"?'),
                                                                    actions: [
                                                                      TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Batal')),
                                                                      TextButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
                                                                    ],
                                                                  ),
                                                                );
                                                                if (confirm == true) {
                                                                  await isar.writeTxn(() async => await isar.categorys.delete(c.id));
                                                                  if (selectedCategoryId == c.syncId) {
                                                                    setModalState(() { selectedCategoryId = null; selectedCategoryName = null; });
                                                                  }
                                                                }
                                                              },
                                                              child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                                            ),
                                                          ],
                                                        ),
                                                        onTap: () {
                                                          Navigator.pop(ctx);
                                                          setModalState(() { selectedCategoryId = c.syncId; selectedCategoryName = c.name; categoryError = null; });
                                                        },
                                                      )),
                                                      ListTile(
                                                        leading: const Icon(Icons.add_circle_outline, color: Colors.blue),
                                                        title: const Text('Tambah Kategori Baru', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                                                        onTap: () async {
                                                          Navigator.pop(ctx);
                                                          final catNameCtrl = TextEditingController();
                                                          final newCatName = await showDialog<String>(
                                                            context: context,
                                                            builder: (dCtx) => AlertDialog(
                                                              title: const Text('Kategori Baru'),
                                                              content: TextField(controller: catNameCtrl, decoration: const InputDecoration(hintText: 'Nama Kategori')),
                                                              actions: [
                                                                TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Batal')),
                                                                TextButton(onPressed: () => Navigator.pop(dCtx, catNameCtrl.text.trim()), child: const Text('Simpan')),
                                                              ],
                                                            ),
                                                          );
                                                          if (newCatName != null && newCatName.isNotEmpty) {
                                                            final newCat = Category()..syncId = await UuidHelper.generatePrefixed()..name = newCatName..createdAt = DateTime.now()..updatedAt = DateTime.now();
                                                            await isar.writeTxn(() async => await isar.categorys.put(newCat));
                                                            setModalState(() { selectedCategoryId = newCat.syncId; selectedCategoryName = newCatName; categoryError = null; });
                                                          }
                                                        },
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              child: InputDecorator(
                                isEmpty: selectedCategoryName == null,
                                decoration: InputDecoration(
                                  labelText: 'Kategori',
                                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  errorText: categoryError,
                                  suffixIcon: const Icon(Icons.keyboard_arrow_down, size: 20),
                                ),
                                child: Text(selectedCategoryName ?? '', style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Row 3: Satuan (full width, separate row)
                      Row(
                        children: [
                          const Icon(Icons.category_outlined, size: 28, color: Colors.black87),
                          const SizedBox(width: 16),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                                  builder: (ctx) => StatefulBuilder(
                                    builder: (ctx, setBottomSheetState) => SafeArea(
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.55),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                                            const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Pilih Satuan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                            Flexible(
                                              child: ListView(
                                                shrinkWrap: true,
                                                children: [
                                                  ...availableUnits.map((u) => ListTile(
                                                    title: Text(u),
                                                    trailing: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        if (u == selectedUnit) const Icon(Icons.check_circle, color: Colors.blue, size: 20),
                                                        const SizedBox(width: 8),
                                                        GestureDetector(
                                                          onTap: () async {
                                                            final confirm = await showDialog<bool>(
                                                              context: ctx,
                                                              builder: (dCtx) => AlertDialog(
                                                                title: const Text('Hapus Satuan?'),
                                                                content: Text('Hapus satuan "$u"?'),
                                                                actions: [
                                                                  TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Batal')),
                                                                  TextButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
                                                                ],
                                                              ),
                                                            );
                                                            if (confirm == true) {
                                                              setBottomSheetState(() {
                                                                availableUnits.remove(u);
                                                              });
                                                              setModalState(() {
                                                                if (selectedUnit == u) selectedUnit = null;
                                                              });
                                                            }
                                                          },
                                                          child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                                        ),
                                                      ],
                                                    ),
                                                    onTap: () {
                                                      Navigator.pop(ctx);
                                                      setModalState(() { selectedUnit = u; unitError = null; });
                                                    },
                                                  )),
                                                  ListTile(
                                                    leading: const Icon(Icons.add_circle_outline, color: Colors.blue),
                                                    title: const Text('Tambah Satuan Baru', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                                                    onTap: () async {
                                                      Navigator.pop(ctx);
                                                      final unitCtrl = TextEditingController();
                                                      final newUnit = await showDialog<String>(
                                                        context: context,
                                                        builder: (dCtx) => AlertDialog(
                                                          title: const Text('Satuan Baru'),
                                                          content: TextField(controller: unitCtrl, decoration: const InputDecoration(hintText: 'Nama Satuan (cth: renceng)')),
                                                          actions: [
                                                            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Batal')),
                                                            TextButton(onPressed: () => Navigator.pop(dCtx, unitCtrl.text.trim()), child: const Text('Simpan')),
                                                          ],
                                                        ),
                                                      );
                                                      if (newUnit != null && newUnit.isNotEmpty) {
                                                        setBottomSheetState(() {
                                                          if (!availableUnits.contains(newUnit)) availableUnits.add(newUnit);
                                                        });
                                                        setModalState(() { selectedUnit = newUnit; unitError = null; });
                                                      }
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              child: InputDecorator(
                                isEmpty: selectedUnit == null,
                                decoration: InputDecoration(
                                  labelText: 'Satuan',
                                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  errorText: unitError,
                                  suffixIcon: const Icon(Icons.keyboard_arrow_down, size: 20),
                                ),
                                child: Text(selectedUnit ?? '', style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Row 4: Harga
                      Row(
                        children: [
                          const Icon(Icons.sell_outlined, size: 28, color: Colors.black87),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: originalPriceController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Harga asli',
                                floatingLabelBehavior: FloatingLabelBehavior.auto,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: priceController,
                              keyboardType: TextInputType.number,
                              onChanged: (_) { if (priceError != null) setModalState(() => priceError = null); },
                              decoration: InputDecoration(
                                labelText: 'Harga jual',
                                floatingLabelBehavior: FloatingLabelBehavior.auto,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                errorText: priceError,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Row 5: Foto (square when uploaded)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(top: localImagePath != null ? 40 : 24),
                            child: const Icon(Icons.image_outlined, size: 28, color: Colors.black87),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: localImagePath != null
                              ? AspectRatio(
                                  aspectRatio: 1,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade400),
                                    ),
                                    child: Stack(
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (previewCtx) => Dialog(
                                                backgroundColor: Colors.transparent,
                                                insetPadding: const EdgeInsets.all(32),
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    ClipRRect(
                                                      borderRadius: BorderRadius.circular(16),
                                                      child: AspectRatio(
                                                        aspectRatio: 1,
                                                        child: _buildProductImage(localImagePath!),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    ElevatedButton.icon(
                                                      onPressed: () => Navigator.pop(previewCtx),
                                                      icon: const Icon(Icons.close, size: 18),
                                                      label: const Text('Tutup'),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.white,
                                                        foregroundColor: Colors.black87,
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: SizedBox(
                                              width: double.infinity,
                                              height: double.infinity,
                                              child: _buildProductImage(localImagePath!, fit: BoxFit.cover),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          right: 8, top: 8,
                                          child: GestureDetector(
                                            onTap: () => setModalState(() => localImagePath = null),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                                              child: const Icon(Icons.close, color: Colors.red, size: 20),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : GestureDetector(
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                                      builder: (ctx) => SafeArea(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                                            const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Unggah Foto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                            ListTile(
                                              leading: const Icon(Icons.camera_alt_outlined, color: Colors.blue),
                                              title: const Text('Kamera'),
                                              onTap: () async {
                                                Navigator.pop(ctx);
                                                final picker = ImagePicker();
                                                final image = await picker.pickImage(source: ImageSource.camera, imageQuality: 100, preferredCameraDevice: CameraDevice.rear);
                                                if (image != null) {
                                                  final cropped = await ImageCropper().cropImage(sourcePath: image.path, aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1), compressQuality: 100);
                                                  if (cropped != null) {
                                                    final targetPath = '${cropped.path.substring(0, cropped.path.lastIndexOf('.'))}_c.webp';
                                                    final compressed = await FlutterImageCompress.compressAndGetFile(
                                                      cropped.path, targetPath, format: CompressFormat.webp, quality: 75,
                                                    );
                                                    if (compressed != null) setModalState(() => localImagePath = compressed.path);
                                                  }
                                                }
                                              },
                                            ),
                                            ListTile(
                                              leading: const Icon(Icons.photo_library_outlined, color: Colors.blue),
                                              title: const Text('Dari Galeri'),
                                              onTap: () async {
                                                Navigator.pop(ctx);
                                                final picker = ImagePicker();
                                                final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
                                                if (image != null) {
                                                  final cropped = await ImageCropper().cropImage(sourcePath: image.path, aspectRatio: CropAspectRatio(ratioX: 1, ratioY: 1), compressQuality: 100);
                                                  if (cropped != null) {
                                                    final targetPath = '${cropped.path.substring(0, cropped.path.lastIndexOf('.'))}_c.webp';
                                                    final compressed = await FlutterImageCompress.compressAndGetFile(
                                                      cropped.path, targetPath, format: CompressFormat.webp, quality: 75,
                                                    );
                                                    if (compressed != null) setModalState(() => localImagePath = compressed.path);
                                                  }
                                                }
                                              },
                                            ),
                                            const SizedBox(height: 16),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8EEF8),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade400),
                                    ),
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.upload_file_outlined, size: 24, color: Colors.black54),
                                        SizedBox(height: 4),
                                        Text('Unggah Foto', style: TextStyle(color: Colors.black54)),
                                      ],
                                    ),
                                  ),
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Row 6: Barcode (dynamic layout)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.qr_code_scanner_outlined, size: 28, color: Colors.black87),
                          const SizedBox(width: 16),
                          if (hasBarcode && barcodeController.text.isEmpty) ...[
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _scanBarcode(context, barcodeController, setModalState),
                                child: Container(
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8EEF8),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade400),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.upload_file_outlined, size: 24, color: Colors.black54),
                                      SizedBox(height: 4),
                                      Text('Unggah barcode', style: TextStyle(color: Colors.black54)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => setModalState(() { hasBarcode = false; barcodeController.clear(); }),
                              child: Container(
                                height: 80,
                                width: 80,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFBE9E7),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade400),
                                ),
                                child: const Center(
                                  child: Text('Tanpa\nbarcode', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 13)),
                                ),
                              ),
                            ),
                          ] else if (!hasBarcode) ...[
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setModalState(() => hasBarcode = true),
                                child: Container(
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Text('Tanpa barcode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            Expanded(
                              child: Container(
                                height: 80,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8EEF8),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade400),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Text(barcodeController.text, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    Positioned(
                                      right: 8, top: 8,
                                      child: GestureDetector(
                                        onTap: () => setModalState(() => barcodeController.clear()),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                                          child: const Icon(Icons.close, color: Colors.red, size: 20),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Row 7: Stok
                      Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 28, color: Colors.black87),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: stockController,
                              keyboardType: TextInputType.number,
                              onChanged: (_) { if (stockError != null) setModalState(() => stockError = null); },
                              decoration: InputDecoration(
                                labelText: 'Stok',
                                floatingLabelBehavior: FloatingLabelBehavior.auto,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                errorText: stockError,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Button Simpan
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () async {
                            final name = nameController.text.trim();
                            final originalPrice = double.tryParse(originalPriceController.text.trim());
                            final price = double.tryParse(priceController.text.trim()) ?? 0;
                            final stock = int.tryParse(stockController.text.trim()) ?? 0;
                            final barcode = barcodeController.text.trim();

                            List<String> errors = [];
                            if (name.isEmpty) { nameError = 'Wajib diisi'; errors.add('Nama barang'); }
                            if (selectedCategoryId == null) { categoryError = 'Wajib diisi'; errors.add('Kategori'); }
                            if (selectedUnit == null) { unitError = 'Wajib diisi'; errors.add('Satuan'); }
                            if (price <= 0) { priceError = 'Wajib diisi'; errors.add('Harga jual'); }
                            if (stockController.text.trim().isEmpty) { stockError = 'Wajib diisi'; errors.add('Stok'); }

                            if (errors.isNotEmpty) {
                              setModalState(() {});
                              if (!context.mounted) return;
                              showDialog(
                                context: context,
                                builder: (dCtx) => Dialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
                                        const SizedBox(height: 12),
                                        const Text('Data Belum Lengkap', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                        const SizedBox(height: 12),
                                        Text('Kolom berikut wajib diisi:', style: TextStyle(color: Colors.grey.shade600)),
                                        const SizedBox(height: 8),
                                        ...errors.map((e) => Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 2),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.circle, size: 6, color: Colors.red),
                                              const SizedBox(width: 8),
                                              Text(e, style: const TextStyle(color: Colors.red)),
                                            ],
                                          ),
                                        )),
                                        const SizedBox(height: 20),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: () => Navigator.pop(dCtx),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF0D47A1),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                            ),
                                            child: const Text('Mengerti', style: TextStyle(color: Colors.white)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                              return;
                            }

                            await isar.writeTxn(() async {
                              if (isEdit) {
                                product.name = name;
                                product.originalPrice = originalPrice;
                                product.price = price;
                                product.stock = stock;
                                product.unit = selectedUnit!;
                                product.barcode = hasBarcode ? barcode : null;
                                product.imageUrl = localImagePath;
                                product.categoryId = selectedCategoryId!;
                                product.updatedAt = DateTime.now();
                                product.isSynced = false;
                                await isar.products.put(product);
                              } else {
                                final newProduct = Product()
                                  ..syncId = await UuidHelper.generatePrefixed()
                                  ..name = name
                                  ..originalPrice = originalPrice
                                  ..price = price
                                  ..stock = stock
                                  ..unit = selectedUnit!
                                  ..barcode = hasBarcode ? barcode : null
                                  ..imageUrl = localImagePath
                                  ..categoryId = selectedCategoryId!
                                  ..createdAt = DateTime.now()
                                  ..updatedAt = DateTime.now();
                                await isar.products.put(newProduct);
                              }
                            });

                            if (context.mounted) Navigator.pop(context);

                            // Modern success popup
                            if (outerContext.mounted) {
                              showDialog(
                                context: outerContext,
                                barrierDismissible: true,
                                builder: (successCtx) {
                                  Future.delayed(const Duration(seconds: 2), () {
                                    if (successCtx.mounted) Navigator.of(successCtx).pop();
                                  });
                                  return Dialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                                            child: Icon(Icons.check_circle, color: Colors.green.shade600, size: 56),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            isEdit ? 'Berhasil Diperbarui!' : 'Berhasil Ditambahkan!',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                          ),
                                          const SizedBox(height: 8),
                                          Text('Data barang berhasil disimpan', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D47A1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          ),
                          child: const Text('Simpan', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _scanBarcode(BuildContext context, TextEditingController controller, StateSetter setModalState) {
    final scanController = MobileScannerController();
    bool isFlashOn = false;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setScanState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Scan Barcode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(isFlashOn ? Icons.flash_on : Icons.flash_off, color: isFlashOn ? Colors.amber : Colors.grey),
                              onPressed: () {
                                scanController.toggleTorch();
                                setScanState(() => isFlashOn = !isFlashOn);
                              },
                            ),
                            InkWell(
                              onTap: () {
                                scanController.dispose();
                                Navigator.pop(context);
                              },
                              child: const Icon(Icons.close, color: Colors.black87),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 280,
                        height: 280,
                        child: MobileScanner(
                          controller: scanController,
                          onDetect: (capture) {
                            final code = capture.barcodes.firstOrNull?.rawValue;
                            if (code != null) {
                              scanController.dispose();
                              Navigator.pop(context);
                              setModalState(() {
                                controller.text = code;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  void _deleteProduct(BuildContext context, Isar isar, Product product) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Hapus Barang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: product.imageUrl != null
                  ? Image.file(File(product.imageUrl!), width: 80, height: 80, fit: BoxFit.cover)
                  : Container(width: 80, height: 80, color: Colors.grey.shade200, child: const Icon(Icons.image, size: 40, color: Colors.grey)),
              ),
              const SizedBox(height: 16),
              Text('Yakin ingin menghapus "${product.name}"?', textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 8),
              Text('${_currencyFormat.format(product.price)} /${product.unit} (Stok: ${product.stock})', style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal', style: TextStyle(color: Colors.blue)),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await isar.writeTxn(() async {
                        product.isDeleted = true;
                        product.isSynced = false;
                        product.updatedAt = DateTime.now();
                        await isar.products.put(product);
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Barang dihapus'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Hapus', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
