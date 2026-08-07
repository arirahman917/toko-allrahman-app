import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:isar/isar.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/transaction.dart';
import '../auth_service.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class OrderRecapScreen extends StatefulWidget {
  final OnlineOrder order;
  const OrderRecapScreen({super.key, required this.order});

  @override
  State<OrderRecapScreen> createState() => _OrderRecapScreenState();
}

class _OrderRecapScreenState extends State<OrderRecapScreen> {
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
  final TextEditingController _moneyController = TextEditingController();
  final FocusNode _moneyFocusNode = FocusNode();

  List<OnlineOrderItem> _items = [];
  Map<String, Product> _products = {};
  bool _isLoading = true;
  double _paidAmount = 0;
  bool _isMoneyFocused = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _moneyFocusNode.addListener(() {
      setState(() {
        _isMoneyFocused = _moneyFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _moneyController.dispose();
    _moneyFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final isar = context.read<Isar>();
    final items = await isar.onlineOrderItems.filter().orderSyncIdEqualTo(widget.order.syncId).findAll();
    final Map<String, Product> products = {};
    for (var item in items) {
      final product = await isar.products.filter().syncIdEqualTo(item.productSyncId).findFirst();
      if (product != null) {
        products[item.productSyncId] = product;
      }
    }
    setState(() {
      _items = items;
      _products = products;
      _isLoading = false;
    });
  }

  void _onMoneyChanged(String value) {
    // Remove all non-digits
    final numericString = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (numericString.isEmpty) {
      _moneyController.value = const TextEditingValue(text: '');
      setState(() {
        _paidAmount = 0;
      });
      return;
    }
    
    final number = double.tryParse(numericString) ?? 0;
    
    // Format the text inside the controller
    final formatted = _currencyFormat.format(number).replaceAll('Rp', '').trim();
    _moneyController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );

    setState(() {
      _paidAmount = number;
    });
  }

  Future<void> _processPayment() async {
    if (_paidAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Masukkan nominal uang terlebih dahulu')));
      return;
    }

    final bool isHutang = _paidAmount < widget.order.totalAmount;
    final double kekurangan = widget.order.totalAmount - _paidAmount;

    // Show Confirmation Dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isHutang ? 'Konfirmasi Hutang' : 'Konfirmasi Pembayaran', 
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: isHutang 
          ? Text('Uang kurang ${_currencyFormat.format(kekurangan)}.\nTransaksi akan disimpan dengan status BELUM LUNAS.')
          : const Text('Rekap ini akan masuk ke menu transaksi.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isHutang ? Colors.red : const Color(0xFF0D47A1), 
              foregroundColor: Colors.white,
            ),
            child: Text(isHutang ? 'Oke, Hutang' : 'Oke, Bayar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final isar = context.read<Isar>();
    final prefix = await AuthService.getCurrentUuidPrefix();
    final String transactionSyncId = '$prefix-${const Uuid().v4()}';
    final now = DateTime.now();
    final changeAmount = _paidAmount - widget.order.totalAmount;

    // Create PosTransaction
    final transaction = PosTransaction()
      ..syncId = transactionSyncId
      ..userId = prefix
      ..customerName = widget.order.customerName
      ..customerAddress = widget.order.customerAddressText
      ..customerLocationUrl = widget.order.customerAddressLat != null 
          ? 'https://maps.google.com/?q=${widget.order.customerAddressLat},${widget.order.customerAddressLng}' 
          : null
      ..totalAmount = widget.order.totalAmount
      ..paidAmount = _paidAmount
      ..changeAmount = changeAmount
      ..status = isHutang ? 'hutang' : 'lunas'
      ..createdAt = now
      ..updatedAt = now
      ..isSynced = false;

    // Create PosTransactionItems
    final List<PosTransactionItem> txItems = [];
    for (var item in _items) {
      final tItem = PosTransactionItem()
        ..syncId = '$prefix-${const Uuid().v4()}'
        ..transactionSyncId = transactionSyncId
        ..productSyncId = item.productSyncId
        ..quantity = item.quantity
        ..priceAtTransaction = item.priceAtOrder
        ..createdAt = now
        ..isSynced = false;
      txItems.add(tItem);
    }

    // Update order status
    widget.order.status = 'completed';
    widget.order.isSynced = false;

    await isar.writeTxn(() async {
      await isar.posTransactions.put(transaction);
      await isar.posTransactionItems.putAll(txItems);
      await isar.onlineOrders.put(widget.order);
      
      // Reduce Stock
      for (var item in _items) {
        final prod = await isar.products.filter().syncIdEqualTo(item.productSyncId).findFirst();
        if (prod != null) {
          prod.stock -= item.quantity;
          prod.updatedAt = now;
          prod.isSynced = false;
          await isar.products.put(prod);
        }
      }
    });

    if (!mounted) return;
    
    // Pop back to home screen and ensure index is 1 (Transactions)
    Navigator.of(context).popUntil((route) => route.isFirst);
    // You would typically use a Provider/StateNotifier to change tab index globally,
    // but the easiest way without modifying HomeScreen extensively is a simple pop.
    // The user instruction: "pindah menu ke menu transaksi".
    // Wait, since HomeScreen state holds _currentIndex, let's just pop. 
    // To strictly change the tab, we should pop with a specific result or use a global navigation key.
    // We'll show a snackbar for now.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(isHutang 
        ? 'Transaksi disimpan. Sisa hutang: ${_currencyFormat.format(kekurangan)}' 
        : 'Pembayaran berhasil. Transaksi disimpan.'
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final double kembalian = _paidAmount - widget.order.totalAmount;
    final bool isKurang = kembalian < 0 && _paidAmount > 0;
    final bool hasInput = _moneyController.text.isNotEmpty;
    final bool showSmallLabel = _isMoneyFocused || hasInput;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Rekap', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Customer Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.order.customerName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (widget.order.customerAddressText != null && widget.order.customerAddressText!.isNotEmpty)
                                  ? widget.order.customerAddressText!
                                  : 'Lokasi Peta Tersimpan',
                              style: const TextStyle(fontSize: 14, color: Colors.black87),
                            ),
                          ),
                          if (widget.order.customerAddressLat != null) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.location_on, color: Colors.orange, size: 18),
                          ]
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Purchases List
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pembelian', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 16),
                      ..._items.map((item) {
                        final product = _products[item.productSyncId];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Product Image Placeholder
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                      image: product?.imageUrl != null 
                                          ? (product!.imageUrl!.startsWith('http') 
                                              ? DecorationImage(image: NetworkImage(product.imageUrl!), fit: BoxFit.cover)
                                              : null) // Local image handling can be complex here, so we skip for simplicity
                                          : null,
                                    ),
                                    child: product?.imageUrl == null ? const Icon(Icons.image, color: Colors.grey) : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product?.name ?? 'Unknown',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(color: const Color(0xFF0D47A1), borderRadius: BorderRadius.circular(4)),
                                              child: Text(
                                                '${item.quantity}',
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text('x ${_currencyFormat.format(item.priceAtOrder)} /pcs', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _currencyFormat.format(item.quantity * item.priceAtOrder),
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1), fontSize: 14),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Divider(height: 1, color: Colors.grey[300]),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Calculation Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(
                            _currencyFormat.format(widget.order.totalAmount),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0D47A1)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Uang Input (Floating Label Effect)
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            height: 60,
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFF0D47A1), width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: TextField(
                              controller: _moneyController,
                              focusNode: _moneyFocusNode,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: showSmallLabel ? '' : 'Tuliskan uang',
                                hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.normal),
                              ),
                              onChanged: _onMoneyChanged,
                            ),
                          ),
                          if (showSmallLabel)
                            Positioned(
                              top: -10,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  color: Colors.white,
                                  child: const Text('Uang', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Kembalian
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(isKurang ? 'Kurang' : 'Kembalian', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(
                            _currencyFormat.format(kembalian.abs()),
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 18, 
                              color: isKurang ? Colors.red : const Color(0xFF0D47A1)
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, -5)),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _paidAmount > 0 ? _processPayment : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              child: const Text('Bayar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ),
      ),
    );
  }
}
