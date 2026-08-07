import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../uuid_helper.dart';
import '../models/transaction.dart';
import '../models/product.dart';
import '../models/cart_item.dart';

/// Formats numeric input with dot separators for thousands (e.g. 500.000)
class _ThousandSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
    final number = int.parse(digits);
    final formatted = NumberFormat('#,###', 'id_ID').format(number);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class PosRecapScreen extends StatefulWidget {
  final List<CartItem> cart;

  const PosRecapScreen({super.key, required this.cart});

  @override
  State<PosRecapScreen> createState() => _PosRecapScreenState();
}

class _PosRecapScreenState extends State<PosRecapScreen> {
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
  final TextEditingController _customerController = TextEditingController(text: 'Fulan');
  final TextEditingController _paidController = TextEditingController();
  
  late List<CartItem> _cart;

  @override
  void initState() {
    super.initState();
    _cart = widget.cart;
    _paidController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _customerController.dispose();
    _paidController.dispose();
    super.dispose();
  }

  double get _totalPrice {
    return _cart.fold(0, (total, item) => total + (item.product.price * item.quantity));
  }

  double get _paidAmount {
    return double.tryParse(_paidController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  void _showEditQuantityModal(CartItem item) {
    final maxQty = item.product.stock + item.quantity; // current stock + already reserved
    final qtyController = TextEditingController(text: '${item.quantity}');
    int tempQty = item.quantity;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 20, left: 24, right: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                const Text('Ubah Satuan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(item.product.name, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (tempQty > 1) {
                          setModalState(() {
                            tempQty--;
                            qtyController.text = '$tempQty';
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.3), blurRadius: 8)]),
                        child: const Icon(Icons.remove, color: Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(width: 20),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: qtyController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (val) {
                          final parsed = int.tryParse(val) ?? 0;
                          setModalState(() {
                            tempQty = parsed.clamp(1, maxQty);
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 20),
                    GestureDetector(
                      onTap: () {
                        if (tempQty < maxQty) {
                          setModalState(() {
                            tempQty++;
                            qtyController.text = '$tempQty';
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.3), blurRadius: 8)]),
                        child: const Icon(Icons.add, color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Maks: $maxQty', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () {
                      final finalQty = tempQty.clamp(1, maxQty);
                      setState(() {
                        item.quantity = finalQty;
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  void _processPayment() async {
    final paid = _paidAmount;
    final total = _totalPrice;

    if (_cart.isEmpty) return;

    if (paid <= 0 && total > 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uang belum dimasukkan')));
      return;
    }

    final isar = context.read<Isar>();
    final txSyncId = await UuidHelper.generatePrefixed();
    final customer = _customerController.text.trim().isEmpty ? 'Fulan' : _customerController.text.trim();
    final status = paid >= total ? 'lunas' : 'hutang';

    await isar.writeTxn(() async {
      final tx = PosTransaction()
        ..syncId = txSyncId
        ..userId = 'local-user'
        ..customerName = customer
        ..totalAmount = total
        ..paidAmount = paid
        ..changeAmount = (paid - total).clamp(0, double.infinity)
        ..status = status
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();
      
      await isar.posTransactions.put(tx);

      for (var item in _cart) {
        final txItem = PosTransactionItem()
          ..syncId = await UuidHelper.generatePrefixed()
          ..transactionSyncId = txSyncId
          ..productSyncId = item.product.syncId
          ..quantity = item.quantity
          ..priceAtTransaction = item.product.price
          ..createdAt = DateTime.now();

        await isar.posTransactionItems.put(txItem);

        // Deduct stock
        item.product.stock -= item.quantity;
        item.product.updatedAt = DateTime.now();
        item.product.isSynced = false;
        await isar.products.put(item.product);
      }
    });

    // Show modern success popup
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 16),
              const Text('Berhasil', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Rekap ini akan masuk ke menu transaksi', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(dCtx); // Close dialog
                    Navigator.pop(context, true); // Return to scanner with true
                  },
                  child: const Text('Tutup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double diff = _paidAmount - _totalPrice;
    final bool isKurang = _paidAmount > 0 && diff < 0;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Rekap', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer Name Input
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                child: TextField(
                  controller: _customerController,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: InputBorder.none,
                    suffixIcon: Icon(Icons.edit, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              const Text('Pembelian', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              
              // Purchase List
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < _cart.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            // Product Image
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _cart[i].product.imageUrl != null
                                    ? (_cart[i].product.imageUrl!.startsWith('http')
                                        ? Image.network(_cart[i].product.imageUrl!, fit: BoxFit.cover)
                                        : Image.file(File(_cart[i].product.imageUrl!), fit: BoxFit.cover))
                                    : const Icon(Icons.inventory_2, color: Colors.grey),
                              ),
                            ),
                            const SizedBox(width: 12),
                            
                            // Product Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_cart[i].product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => _showEditQuantityModal(_cart[i]),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.blue.shade700, borderRadius: BorderRadius.circular(6)),
                                          child: Text('${_cart[i].quantity}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text('× ${_currencyFormat.format(_cart[i].product.price)} /${_cart[i].product.unit}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12), overflow: TextOverflow.ellipsis),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            
                            // Total price & Delete
                            Text(
                              _currencyFormat.format(_cart[i].product.price * _cart[i].quantity),
                              style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _cart.removeAt(i);
                                });
                              },
                              child: const Icon(Icons.delete, color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                      if (i < _cart.length - 1)
                        Divider(height: 1, color: Colors.blue.shade100, thickness: 1),
                    ],
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Tambah Barang Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add, color: Colors.black54),
                  label: const Text('Tambah barang', style: TextStyle(color: Colors.black54)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Payment Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text(_currencyFormat.format(_totalPrice), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 20)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Uang Input with Rp prefix and auto-formatted
                    TextField(
                      controller: _paidController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 22, fontWeight: FontWeight.bold),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _ThousandSeparatorInputFormatter(),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Uang',
                        hintText: 'Tuliskan uang...',
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.normal),
                        floatingLabelBehavior: FloatingLabelBehavior.auto,
                        prefixIcon: Container(
                          width: 40,
                          alignment: Alignment.center,
                          child: const Text('Rp', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.blue, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.blue, width: 2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.blue, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isKurang ? 'Kurang' : 'Kembalian',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isKurang ? Colors.red : Colors.black),
                        ),
                        Text(
                          isKurang
                            ? _currencyFormat.format(diff.abs())
                            : _currencyFormat.format(diff.clamp(0, double.infinity)),
                          style: TextStyle(color: isKurang ? Colors.red : Colors.blue, fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Bayar Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _cart.isEmpty ? null : _processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: const Text('Bayar', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
