import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/cart_item.dart';

enum SortOption { az, za, stockLowHigh, stockHighLow }

class PosManualInputScreen extends StatefulWidget {
  final List<CartItem> initialCart;
  
  const PosManualInputScreen({super.key, required this.initialCart});

  @override
  State<PosManualInputScreen> createState() => _PosManualInputScreenState();
}

class _PosManualInputScreenState extends State<PosManualInputScreen> {
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
  
  String _searchQuery = '';
  String? _selectedCategory;
  SortOption _currentSort = SortOption.az;
  
  // Clone cart to local state
  late List<CartItem> _cart;

  @override
  void initState() {
    super.initState();
    // Deep clone the initial cart so we can edit quantities locally
    _cart = widget.initialCart.map((item) => CartItem(product: item.product, quantity: item.quantity)).toList();
    
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _finishSelection() {
    Navigator.pop(context, _cart);
  }

  int _getQuantity(Product product) {
    final existing = _cart.where((c) => c.product.id == product.id).toList();
    if (existing.isNotEmpty) {
      return existing.first.quantity;
    }
    return 0;
  }

  void _setQuantity(Product product, int newQty) {
    setState(() {
      final existingIndex = _cart.indexWhere((c) => c.product.id == product.id);
      if (newQty <= 0) {
        if (existingIndex >= 0) _cart.removeAt(existingIndex);
      } else {
        if (existingIndex >= 0) {
          _cart[existingIndex].quantity = newQty;
        } else {
          _cart.add(CartItem(product: product, quantity: newQty));
        }
      }
    });
  }

  Widget _buildCategoryChip(String label, String? syncId) {
    final isSelected = _selectedCategory == syncId;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(color: isSelected ? Colors.blue.shade700 : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = selected ? syncId : null;
          });
        },
        selectedColor: Colors.blue.shade50,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isSelected ? Colors.blue : Colors.grey.shade300),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isar = context.read<Isar>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 28),
          onPressed: () => Navigator.pop(context, _cart),
        ),
        title: const Text('Input Manual', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _searchController,
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
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: PopupMenuButton<SortOption>(
                    icon: const Icon(Icons.tune, color: Colors.blue),
                    offset: const Offset(0, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (val) => setState(() => _currentSort = val),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: _currentSort == SortOption.az ? SortOption.za : SortOption.az,
                        child: Row(
                          children: [
                            const Icon(Icons.sort_by_alpha, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(_currentSort == SortOption.az ? 'Urutkan Z-A' : 'Urutkan A-Z'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: _currentSort == SortOption.stockLowHigh ? SortOption.stockHighLow : SortOption.stockLowHigh,
                        child: Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(_currentSort == SortOption.stockLowHigh ? 'Stok: Banyak ke Sedikit' : 'Stok: Sedikit ke Banyak'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Category Chips
          StreamBuilder<List<Category>>(
            stream: isar.categorys.where().watch(fireImmediately: true),
            builder: (context, snapshot) {
              final categories = snapshot.data ?? [];
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    _buildCategoryChip('Semua', null),
                    ...categories.map((cat) => _buildCategoryChip(cat.name, cat.syncId)),
                  ],
                ),
              );
            },
          ),
          
          const SizedBox(height: 8),
          
          // Product List
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: isar.products.where().watch(fireImmediately: true),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                var products = snapshot.data ?? [];
                
                // Filtering
                if (_searchQuery.isNotEmpty) {
                  products = products.where((p) => p.name.toLowerCase().contains(_searchQuery)).toList();
                }
                if (_selectedCategory != null) {
                  products = products.where((p) => p.categoryId == _selectedCategory).toList();
                }
                
                // Sorting
                switch (_currentSort) {
                  case SortOption.az:
                    products.sort((a, b) => a.name.compareTo(b.name));
                    break;
                  case SortOption.za:
                    products.sort((a, b) => b.name.compareTo(a.name));
                    break;
                  case SortOption.stockLowHigh:
                    products.sort((a, b) => a.stock.compareTo(b.stock));
                    break;
                  case SortOption.stockHighLow:
                    products.sort((a, b) => b.stock.compareTo(a.stock));
                    break;
                }
                
                if (products.isEmpty) {
                  return const Center(child: Text('Tidak ada produk.'));
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final qty = _getQuantity(product);
                    final isPicked = qty > 0;
                    
                    return GestureDetector(
                      onTap: () {
                        if (!isPicked) {
                          if (product.stock > 0) {
                            _setQuantity(product, 1);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stok habis!')));
                          }
                        } else {
                          // Unpick if tapped again on the card body (optional, but requested in requirement "jika unpick balik lagi ke drop shadow")
                          // Actually, unpick happens when qty hits 0. We'll let them use the - button.
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isPicked ? Colors.blue.shade50.withOpacity(0.3) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isPicked ? Colors.blue.shade300 : Colors.grey.shade200, width: isPicked ? 2 : 1),
                          boxShadow: isPicked ? [] : [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product Image
                            GestureDetector(
                              onTap: () {
                                // Show Image Preview
                                if (product.imageUrl != null) {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => Dialog(
                                      backgroundColor: Colors.transparent,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: product.imageUrl!.startsWith('http')
                                            ? Image.network(product.imageUrl!, fit: BoxFit.contain)
                                            : Image.file(File(product.imageUrl!), fit: BoxFit.contain),
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 70,
                                  height: 70,
                                  color: Colors.grey.shade100,
                                  child: product.imageUrl != null
                                      ? (product.imageUrl!.startsWith('http')
                                          ? Image.network(product.imageUrl!, fit: BoxFit.cover)
                                          : Image.file(File(product.imageUrl!), fit: BoxFit.cover))
                                      : const Icon(Icons.inventory_2, color: Colors.grey),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            
                            // Product Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  RichText(
                                    text: TextSpan(
                                      style: const TextStyle(color: Colors.black, fontSize: 14),
                                      children: [
                                        TextSpan(text: _currencyFormat.format(product.price), style: const TextStyle(fontWeight: FontWeight.bold)),
                                        TextSpan(text: ' /${product.unit}', style: const TextStyle(color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Right Side: Stock Badge & Qty Editor
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Builder(
                                  builder: (context) {
                                    Color bgColor;
                                    Color textColor;
                                    if (product.stock == 0) {
                                      bgColor = Colors.red.shade100;
                                      textColor = Colors.red.shade800;
                                    } else if (product.stock <= 3) {
                                      bgColor = Colors.yellow.shade100;
                                      textColor = Colors.orange.shade800;
                                    } else {
                                      bgColor = Colors.blue.shade100;
                                      textColor = Colors.blue.shade800;
                                    }
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: bgColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text('Stok: ${product.stock}', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                    );
                                  },
                                ),
                                if (isPicked) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        onTap: () => _setQuantity(product, qty - 1),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                          child: const Icon(Icons.remove, color: Colors.white, size: 16),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(width: 12),
                                      GestureDetector(
                                        onTap: () {
                                          if (qty < product.stock) {
                                            _setQuantity(product, qty + 1);
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Melebihi stok maksimal')));
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                          child: const Icon(Icons.add, color: Colors.white, size: 16),
                                        ),
                                      ),
                                    ],
                                  )
                                ]
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
      
      // Giant Green Checklist Button
      floatingActionButton: FloatingActionButton(
        onPressed: _finishSelection,
        backgroundColor: Colors.green,
        elevation: 6,
        child: const Icon(Icons.check, color: Colors.white, size: 36),
      ),
    );
  }
}
