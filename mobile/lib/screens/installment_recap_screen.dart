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

class InstallmentRecapScreen extends StatefulWidget {
  final PosTransaction transaction;

  const InstallmentRecapScreen({super.key, required this.transaction});

  @override
  State<InstallmentRecapScreen> createState() => _InstallmentRecapScreenState();
}

class _InstallmentRecapScreenState extends State<InstallmentRecapScreen> {
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
  final TextEditingController _paidController = TextEditingController();
  
  List<PosTransactionItem> _items = [];
  Map<String, Product> _productMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _paidController.addListener(() {
      setState(() {});
    });
  }

  Future<void> _loadItems() async {
    final isar = Provider.of<Isar>(context, listen: false);
    final items = await isar.posTransactionItems.filter().transactionSyncIdEqualTo(widget.transaction.syncId).findAll();
    
    // Load product details for images/names
    final pMap = <String, Product>{};
    for (var item in items) {
      final product = await isar.products.filter().syncIdEqualTo(item.productSyncId).findFirst();
      if (product != null) {
        pMap[item.productSyncId] = product;
      }
    }
    
    setState(() {
      _items = items;
      _productMap = pMap;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _paidController.dispose();
    super.dispose();
  }

  double get _paidAmount {
    return double.tryParse(_paidController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }
  
  double get _remainingDebt {
    return widget.transaction.totalAmount - widget.transaction.paidAmount;
  }

  void _processPayment() async {
    final paid = _paidAmount;
    final currentDebt = _remainingDebt;

    if (paid <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uang belum dimasukkan')));
      return;
    }

    final isar = Provider.of<Isar>(context, listen: false);
    final paymentSyncId = await UuidHelper.generatePrefixed();
    
    // Calculate new status and amounts
    final newPaidTotal = widget.transaction.paidAmount + paid;
    final changeOrRemaining = (paid - currentDebt); // Positive = Kembalian, Negative = Masih Kurang
    final status = newPaidTotal >= widget.transaction.totalAmount ? 'lunas' : 'hutang';
    
    final changeForTransaction = changeOrRemaining > 0 ? changeOrRemaining : 0.0;

    await isar.writeTxn(() async {
      // 1. Create Payment History
      final history = PosPaymentHistory()
        ..syncId = paymentSyncId
        ..transactionSyncId = widget.transaction.syncId
        ..paymentAmount = paid
        ..debtBeforePayment = currentDebt
        ..changeOrRemainingDebtAfterPayment = changeOrRemaining
        ..createdAt = DateTime.now()
        ..isSynced = false;
        
      await isar.posPaymentHistorys.put(history);

      // 2. Update Transaction
      widget.transaction.paidAmount = newPaidTotal;
      widget.transaction.changeAmount += changeForTransaction; // Accumulate change if any
      widget.transaction.status = status;
      widget.transaction.updatedAt = DateTime.now();
      widget.transaction.isSynced = false;
      
      await isar.posTransactions.put(widget.transaction);
    });

    if (!mounted) return;
    
    // Show success popup
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
              Text(status == 'lunas' ? 'Hutang telah dilunasi' : 'Angsuran berhasil dicatat', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
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
                    Navigator.pop(context); // Return to transaction list
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
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    final double diff = _paidAmount - _remainingDebt;
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
              // Customer Name (Read Only)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                child: Text(widget.transaction.customerName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 24),
              
              const Text('Pembelian', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              
              // Purchase List (Read Only)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < _items.length; i++) ...[
                      Builder(
                        builder: (context) {
                          final item = _items[i];
                          final product = _productMap[item.productSyncId];
                          final productName = product?.name ?? 'Produk Dihapus';
                          final productImg = product?.imageUrl;
                          
                          return Padding(
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
                                    child: productImg != null
                                        ? (productImg.startsWith('http')
                                            ? Image.network(productImg, fit: BoxFit.cover)
                                            : Image.file(File(productImg), fit: BoxFit.cover))
                                        : const Icon(Icons.inventory_2, color: Colors.grey),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                
                                // Product Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(color: Colors.blue.shade700, borderRadius: BorderRadius.circular(6)),
                                            child: Text('${item.quantity}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text('× ${_currencyFormat.format(item.priceAtTransaction)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12), overflow: TextOverflow.ellipsis),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Total price
                                Text(
                                  _currencyFormat.format(item.priceAtTransaction * item.quantity),
                                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                          );
                        }
                      ),
                      if (i < _items.length - 1)
                        Divider(height: 1, color: Colors.blue.shade100, thickness: 1),
                    ],
                  ],
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
                        Text(_currencyFormat.format(widget.transaction.totalAmount), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 20)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Belum Lunas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('− ${_currencyFormat.format(_remainingDebt)}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Uang Input
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
                  onPressed: _processPayment,
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
