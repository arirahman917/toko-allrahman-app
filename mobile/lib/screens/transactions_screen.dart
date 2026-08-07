import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/transaction.dart';
import 'receipt_screen.dart';
import 'installment_recap_screen.dart';

enum TransactionFilterStatus { all, lunas, hutang }
enum TransactionSortOption { az, za }

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
  final DateFormat _dateFormat = DateFormat('d/M/yyyy - HH:mm', 'id_ID');
  
  final TextEditingController _searchController = TextEditingController();
  
  String _searchQuery = '';
  TransactionFilterStatus _filterStatus = TransactionFilterStatus.all;
  TransactionSortOption _sortOption = TransactionSortOption.za; // default newest to oldest visually if we sort by date, but A-Z means by name. Let's make default ZA for name? Wait, standard is A-Z. But usually transactions are sorted by date. The user requested A-Z/Z-A filter. We will sort by Name or Date? The requirement says A-Z/Z-A, so we sort by Customer Name.
  
  DateTime _selectedMonthYear = DateTime.now();

  @override
  void initState() {
    super.initState();
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

  void _showMonthYearPicker() {
    showDialog(
      context: context,
      builder: (context) {
        int tempYear = _selectedMonthYear.year;
        int tempMonth = _selectedMonthYear.month;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Pilih Bulan & Tahun', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, size: 16),
                        onPressed: () => setDialogState(() => tempYear--),
                      ),
                      Text('$tempYear', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, size: 16),
                        onPressed: () => setDialogState(() => tempYear++),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(12, (index) {
                      final monthNum = index + 1;
                      final isSelected = tempMonth == monthNum;
                      return GestureDetector(
                        onTap: () => setDialogState(() => tempMonth = monthNum),
                        child: Container(
                          width: 60,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isSelected ? Colors.blue : Colors.transparent),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            DateFormat('MMM', 'id_ID').format(DateTime(tempYear, monthNum)),
                            style: TextStyle(
                              color: isSelected ? Colors.blue.shade700 : Colors.black87,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedMonthYear = DateTime(tempYear, tempMonth);
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Pilih'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Urutkan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildFilterChip(
                        'A - Z',
                        Icons.sort_by_alpha,
                        _sortOption == TransactionSortOption.az,
                        () {
                          setState(() => _sortOption = TransactionSortOption.az);
                          setModalState(() {});
                        },
                      ),
                      const SizedBox(width: 12),
                      _buildFilterChip(
                        'Z - A',
                        Icons.sort_by_alpha,
                        _sortOption == TransactionSortOption.za,
                        () {
                          setState(() => _sortOption = TransactionSortOption.za);
                          setModalState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Status Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatusChip('Semua', Icons.attach_money, Colors.grey, _filterStatus == TransactionFilterStatus.all, () {
                        setState(() => _filterStatus = TransactionFilterStatus.all);
                        setModalState(() {});
                      }),
                      _buildStatusChip('Lunas', Icons.attach_money, Colors.orange, _filterStatus == TransactionFilterStatus.lunas, () {
                        setState(() => _filterStatus = TransactionFilterStatus.lunas);
                        setModalState(() {});
                      }),
                      _buildStatusChip('Hutang', Icons.attach_money, Colors.red, _filterStatus == TransactionFilterStatus.hutang, () {
                        setState(() => _filterStatus = TransactionFilterStatus.hutang);
                        setModalState(() {});
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildFilterChip(String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.blue : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.blue.shade700 : Colors.black54),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSelected ? Colors.blue.shade700 : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, IconData icon, Color baseColor, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? baseColor.withOpacity(0.2) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? baseColor : Colors.transparent),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: baseColor, shape: BoxShape.circle),
              child: Icon(icon, size: 12, color: Colors.white),
            ),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: isSelected ? baseColor : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isar = Provider.of<Isar>(context);
    final monthStr = DateFormat('MMM, yyyy', 'id_ID').format(_selectedMonthYear);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Transaksi', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24)),
        actions: [
          // Month/Year Picker Button
          GestureDetector(
            onTap: _showMonthYearPicker,
            child: Container(
              margin: const EdgeInsets.only(right: 8, top: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.blue, size: 16),
                  const SizedBox(width: 6),
                  Text(monthStr, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          // Filter Button
          GestureDetector(
            onTap: _showFilterMenu,
            child: Container(
              margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
              width: 40,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.tune, color: Colors.blue),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Cari...',
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
          ),
          
          // Transaction List
          Expanded(
            child: StreamBuilder<List<PosTransaction>>(
              stream: isar.posTransactions.where().watch(fireImmediately: true),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                var transactions = snapshot.data ?? [];
                
                // Filter by Search Query
                if (_searchQuery.isNotEmpty) {
                  transactions = transactions.where((t) => t.customerName.toLowerCase().contains(_searchQuery)).toList();
                }
                
                // Filter by Month & Year
                transactions = transactions.where((t) => 
                  t.createdAt.year == _selectedMonthYear.year && 
                  t.createdAt.month == _selectedMonthYear.month
                ).toList();

                // Filter by Status
                if (_filterStatus == TransactionFilterStatus.lunas) {
                  transactions = transactions.where((t) => t.status == 'lunas').toList();
                } else if (_filterStatus == TransactionFilterStatus.hutang) {
                  transactions = transactions.where((t) => t.status == 'hutang').toList();
                }
                
                // Sort by Name (A-Z or Z-A)
                if (_sortOption == TransactionSortOption.az) {
                  transactions.sort((a, b) => a.customerName.compareTo(b.customerName));
                } else {
                  transactions.sort((a, b) => b.customerName.compareTo(a.customerName));
                }

                if (transactions.isEmpty) {
                  return const Center(child: Text('Tidak ada transaksi.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final trx = transactions[index];
                    final isLunas = trx.status == 'lunas';
                    final remainingDebt = trx.totalAmount - trx.paidAmount;

                    return GestureDetector(
                      onTap: () {
                        if (isLunas) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ReceiptScreen(transaction: trx)),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => InstallmentRecapScreen(transaction: trx)),
                          );
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left side
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(trx.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text(_currencyFormat.format(trx.totalAmount), style: const TextStyle(fontSize: 14)),
                                if (trx.customerAddress != null && trx.customerAddress!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    trx.customerAddress!,
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                if (trx.customerLocationUrl != null) ...[
                                  const SizedBox(height: 4),
                                  InkWell(
                                    onTap: () async {
                                      final url = Uri.parse(trx.customerLocationUrl!);
                                      if (await canLaunchUrl(url)) {
                                        await launchUrl(url, mode: LaunchMode.externalApplication);
                                      }
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.location_on, size: 12, color: Colors.blue),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Buka Peta',
                                          style: TextStyle(fontSize: 11, color: Colors.blue.shade700, decoration: TextDecoration.underline),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            // Right side
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(_dateFormat.format(trx.createdAt), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                                const SizedBox(height: 8),
                                if (isLunas)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('LUNAS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade500,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('(BELUM LUNAS) ', style: TextStyle(color: Colors.white, fontSize: 10)),
                                        Text(_currencyFormat.format(remainingDebt), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                                      ],
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
    );
  }
}
