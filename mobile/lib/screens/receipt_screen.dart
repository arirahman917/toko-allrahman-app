import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/product.dart';

class ReceiptScreen extends StatefulWidget {
  final PosTransaction transaction;

  const ReceiptScreen({super.key, required this.transaction});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
  final DateFormat _dateFormat = DateFormat('d/M/yyyy - HH:mm', 'id_ID');

  List<PosTransactionItem> _items = [];
  List<PosPaymentHistory> _history = [];
  Map<String, Product> _productMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final isar = Provider.of<Isar>(context, listen: false);
    
    // Load Items
    final items = await isar.posTransactionItems.filter().transactionSyncIdEqualTo(widget.transaction.syncId).findAll();
    
    // Load History
    final history = await isar.posPaymentHistorys
        .filter()
        .transactionSyncIdEqualTo(widget.transaction.syncId)
        .sortByCreatedAt()
        .findAll();

    // Load Products
    final pMap = <String, Product>{};
    for (var item in items) {
      final product = await isar.products.filter().syncIdEqualTo(item.productSyncId).findFirst();
      if (product != null) {
        pMap[item.productSyncId] = product;
      }
    }
    
    setState(() {
      _items = items;
      _history = history;
      _productMap = pMap;
      _isLoading = false;
    });
  }

  Widget _buildSummaryBlock({
    required DateTime date,
    required String topLabel,
    required double topAmount,
    required double paidAmount,
    required String bottomLabel,
    required double bottomAmount,
    required Color bottomColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(_dateFormat.format(date), style: const TextStyle(color: Colors.black87, fontSize: 12)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(topLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(_currencyFormat.format(topAmount), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Uang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(_currencyFormat.format(paidAmount), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(bottomLabel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: bottomColor)),
              Text(_currencyFormat.format(bottomAmount), style: TextStyle(color: bottomColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade50,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Struk', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Customer Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(widget.transaction.customerName, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 16),
            
            // Purchase List
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Pembelian', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  for (int i = 0; i < _items.length; i++) ...[
                    Builder(
                      builder: (context) {
                        final item = _items[i];
                        final product = _productMap[item.productSyncId];
                        final productName = product?.name ?? 'Produk Dihapus';
                        final productImg = product?.imageUrl;
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Row(
                            children: [
                              // Image
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
                              
                              // Info
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
                                          child: Text('${item.quantity}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text('× ${_currencyFormat.format(item.priceAtTransaction)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Total
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
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Divider(height: 16, color: Colors.grey),
                      ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Payment History / Summary Blocks
            if (_history.isEmpty)
              // Legacy fallback or single payment
              _buildSummaryBlock(
                date: widget.transaction.createdAt,
                topLabel: 'Total',
                topAmount: widget.transaction.totalAmount,
                paidAmount: widget.transaction.paidAmount,
                bottomLabel: widget.transaction.status == 'lunas' ? 'Kembalian' : 'Kurang',
                bottomAmount: widget.transaction.status == 'lunas' ? widget.transaction.changeAmount : (widget.transaction.totalAmount - widget.transaction.paidAmount),
                bottomColor: widget.transaction.status == 'lunas' ? Colors.blue : Colors.red,
              )
            else
              // Dynamic history rendering
              for (int i = 0; i < _history.length; i++) ...[
                Builder(
                  builder: (context) {
                    final h = _history[i];
                    final isFirst = i == 0;
                    
                    final topLabel = isFirst ? 'Total' : 'Belum Lunas';
                    final topAmount = isFirst ? widget.transaction.totalAmount : h.debtBeforePayment;
                    
                    final isKurang = h.changeOrRemainingDebtAfterPayment < 0;
                    final bottomLabel = isKurang ? 'Kurang' : 'Kembalian';
                    final bottomAmount = h.changeOrRemainingDebtAfterPayment.abs();
                    final bottomColor = isKurang ? Colors.red : Colors.blue;

                    return _buildSummaryBlock(
                      date: h.createdAt,
                      topLabel: topLabel,
                      topAmount: topAmount,
                      paidAmount: h.paymentAmount,
                      bottomLabel: bottomLabel,
                      bottomAmount: bottomAmount,
                      bottomColor: bottomColor,
                    );
                  }
                )
              ],
              
            const SizedBox(height: 32),
            // Logo placeholder
            Column(
              children: [
                Icon(Icons.shopping_bag, size: 40, color: Colors.blue.shade700),
                const SizedBox(height: 8),
                Text('AL RAHMAN', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
                Text('TOKO GROSIR SEMBAKO', style: TextStyle(color: Colors.blue.shade700, fontSize: 8, letterSpacing: 1)),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
