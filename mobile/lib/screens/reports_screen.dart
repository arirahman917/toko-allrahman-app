import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';
import 'login_screen.dart';
import 'package:isar/isar.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/transaction.dart';
import '../models/product.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);
  
  DateTime _selectedMonthYear = DateTime.now();
  String _graph1Type = 'penghasilan'; // 'penghasilan' or 'keuntungan'

  void _showMonthYearPicker() {
    showDialog(
      context: context,
      builder: (context) {
        int tempYear = _selectedMonthYear.year;
        int tempMonth = _selectedMonthYear.month;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue.shade600 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: isSelected ? [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            DateFormat('MMM', 'id_ID').format(DateTime(tempYear, monthNum)),
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
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
                  child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedMonthYear = DateTime(tempYear, tempMonth);
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Pilih', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getAllChartData(Isar isar) async {
    final startOfMonth = DateTime(_selectedMonthYear.year, _selectedMonthYear.month, 1);
    final endOfMonth = DateTime(_selectedMonthYear.year, _selectedMonthYear.month + 1, 0, 23, 59, 59);

    final transactions = await isar.posTransactions
        .filter()
        .createdAtBetween(startOfMonth, endOfMonth)
        .isDeletedEqualTo(false)
        .findAll();

    final daysInMonth = endOfMonth.day;
    final Map<int, double> g1Data = {for (int i = 1; i <= daysInMonth; i++) i: 0.0};
    final Map<int, double> g2Data = {for (int i = 1; i <= daysInMonth; i++) i: 0.0};

    // Preload items and products for profit calculation
    final validTxIds = transactions.map((e) => e.syncId).toSet();
    final allItems = await isar.posTransactionItems.where().findAll();
    final itemsThisMonth = allItems.where((item) => validTxIds.contains(item.transactionSyncId)).toList();
    
    final products = await isar.products.where().findAll();
    final productMap = {for (var p in products) p.syncId: p};

    final Map<String, int> txDays = {for (var tx in transactions) tx.syncId: tx.createdAt.day};

    // Calculate Graph 2 (Total Transactions)
    for (final trx in transactions) {
      final day = trx.createdAt.day;
      g2Data[day] = (g2Data[day] ?? 0) + 1;
    }

    // Calculate Graph 1 (Penghasilan or Keuntungan)
    if (_graph1Type == 'penghasilan') {
      for (final trx in transactions) {
        if (trx.status == 'lunas' || trx.paidAmount > 0) {
          final day = trx.createdAt.day;
          g1Data[day] = (g1Data[day] ?? 0) + (trx.status == 'lunas' ? trx.totalAmount : trx.paidAmount);
        }
      }
    } else if (_graph1Type == 'keuntungan') {
      for (final item in itemsThisMonth) {
        final day = txDays[item.transactionSyncId];
        if (day != null) {
          final p = productMap[item.productSyncId];
          final originalPrice = p?.originalPrice ?? item.priceAtTransaction;
          final profit = (item.priceAtTransaction - originalPrice) * item.quantity;
          g1Data[day] = (g1Data[day] ?? 0) + profit;
        }
      }
    }

    double g1MaxY = 0;
    double g1MinY = 0;
    final List<FlSpot> g1Spots = [];
    g1Data.forEach((day, value) {
      g1Spots.add(FlSpot(day.toDouble(), value));
      if (value > g1MaxY) g1MaxY = value;
      if (value < g1MinY) g1MinY = value;
    });

    double g2MaxY = 0;
    final List<FlSpot> g2Spots = [];
    g2Data.forEach((day, value) {
      g2Spots.add(FlSpot(day.toDouble(), value));
      if (value > g2MaxY) g2MaxY = value;
    });

    return {
      'g1Spots': g1Spots,
      'g1MaxY': g1MaxY,
      'g1MinY': g1MinY < 0 ? g1MinY * 1.2 : 0.0,
      'g2Spots': g2Spots,
      'g2MaxY': g2MaxY,
      'daysInMonth': daysInMonth,
    };
  }

  Future<Map<String, List<Map<String, dynamic>>>> _getProductRankings(Isar isar) async {
    final startOfMonth = DateTime(_selectedMonthYear.year, _selectedMonthYear.month, 1);
    final endOfMonth = DateTime(_selectedMonthYear.year, _selectedMonthYear.month + 1, 0, 23, 59, 59);

    final transactions = await isar.posTransactions
        .filter()
        .createdAtBetween(startOfMonth, endOfMonth)
        .isDeletedEqualTo(false)
        .findAll();
    
    final validTxIds = transactions.map((t) => t.syncId).toSet();
    final allItems = await isar.posTransactionItems.where().findAll();
    final itemsThisMonth = allItems.where((item) => validTxIds.contains(item.transactionSyncId)).toList();
    final allProducts = await isar.products.where().findAll();
    
    final Map<String, int> productQtyMap = {};
    for (final p in allProducts) {
      productQtyMap[p.syncId] = 0;
    }

    for (final item in itemsThisMonth) {
      if (productQtyMap.containsKey(item.productSyncId)) {
        productQtyMap[item.productSyncId] = productQtyMap[item.productSyncId]! + item.quantity;
      }
    }

    final List<Map<String, dynamic>> productStats = [];
    for (final p in allProducts) {
      productStats.add({
        'name': p.name,
        'image': p.imageUrl,
        'qty': productQtyMap[p.syncId] ?? 0,
        'unit': 'renteng/pcs',
      });
    }

    final sortedDesc = List<Map<String, dynamic>>.from(productStats)
      ..sort((a, b) => (b['qty'] as int).compareTo(a['qty'] as int));
    
    final sortedAsc = List<Map<String, dynamic>>.from(productStats)
      ..sort((a, b) => (a['qty'] as int).compareTo(b['qty'] as int));

    return {
      'best': sortedDesc.take(5).toList(),
      'worst': sortedAsc.take(5).toList(),
    };
  }

  Widget _buildLineChart({
    required List<FlSpot> spots, 
    required double minY, 
    required double maxY, 
    required int daysInMonth, 
    required bool isCurrency
  }) {
    final topY = maxY == 0 ? (isCurrency ? 10000.0 : 5.0) : maxY * 1.2;
    // We widen the chart width dynamically based on the number of days so labels don't collide
    // 35px per day ensures plenty of space for 31 labels.
    final chartWidth = daysInMonth * 35.0; 

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        // The container will stretch to screen width if chartWidth is smaller.
        width: chartWidth < MediaQuery.of(context).size.width - 40 ? MediaQuery.of(context).size.width - 40 : chartWidth,
        height: 250,
        // Reduced left padding to push graph to the left edge
        padding: const EdgeInsets.only(right: 20, left: 0, top: 20, bottom: 0),
        child: LineChart(
          LineChartData(
            minX: 1,
            maxX: daysInMonth.toDouble(),
            minY: minY,
            maxY: topY,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false, // Straight line
                color: Colors.blue.shade700,
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 4,
                      color: Colors.white,
                      strokeWidth: 2,
                      strokeColor: Colors.blue.shade700,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.withOpacity(0.15),
                      Colors.blue.withOpacity(0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
            titlesData: FlTitlesData(
              show: true,
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 25,
                  interval: 1, // Show every single date 1-31
                  getTitlesWidget: (value, meta) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        '${value.toInt()}',
                        style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 45, // Reduced from 55 to maximize left space
                  getTitlesWidget: (value, meta) {
                    if (value == topY || value == minY && minY != 0) return const SizedBox.shrink();
                    String text;
                    if (isCurrency) {
                      if (value == 0) {
                        text = 'Rp0';
                      } else {
                        final isNeg = value < 0;
                        final absVal = value.abs();
                        if (absVal >= 1000000) {
                          text = '${isNeg?"-":""}Rp${(absVal/1000000).toStringAsFixed(1)}jt';
                        } else if (absVal >= 1000) {
                          text = '${isNeg?"-":""}Rp${(absVal/1000).toStringAsFixed(0)}k';
                        } else {
                          text = '${isNeg?"-":""}Rp${absVal.toInt()}';
                        }
                      }
                    } else {
                      text = value.toInt().toString();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: Text(
                        text,
                        style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 10),
                        textAlign: TextAlign.right,
                      ),
                    );
                  },
                ),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: (topY - minY) > 0 ? (topY - minY) / 4 : 1,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey.shade200,
                  strokeWidth: 1,
                );
              },
            ),
            borderData: FlBorderData(show: false),
          ),
        ),
      ),
    );
  }

  Widget _buildProductList(String title, List<Map<String, dynamic>> products, bool isWorst) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Terjual', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey.shade500)),
              ],
            ),
          ),
          for (int i = 0; i < products.length; i++) ...[
            Builder(
              builder: (context) {
                final product = products[i];
                final qty = product['qty'] as int;
                final isLow = isWorst && qty <= 5;
                
                // Modern Badge for Ranking
                Color badgeColor;
                if (isWorst) {
                  badgeColor = Colors.red.shade50;
                } else {
                  badgeColor = i == 0 ? Colors.amber.shade50 : (i == 1 ? Colors.grey.shade100 : (i == 2 ? Colors.orange.shade50 : Colors.blue.shade50));
                }
                Color badgeTextColor = isWorst ? Colors.red.shade700 : (i == 0 ? Colors.amber.shade900 : (i == 1 ? Colors.black54 : (i == 2 ? Colors.orange.shade900 : Colors.blue.shade700)));

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      // Rank Badge
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(6)),
                        child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: badgeTextColor)),
                      ),
                      const SizedBox(width: 16),
                      // Image
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: product['image'] != null
                              ? (product['image'].toString().startsWith('http')
                                  ? Image.network(product['image'], fit: BoxFit.cover)
                                  : Image.file(File(product['image']), fit: BoxFit.cover))
                              : const Icon(Icons.inventory_2, color: Colors.grey, size: 20),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Details
                      Expanded(
                        child: Text(product['name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                      // Qty
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$qty',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isLow ? Colors.red : Colors.black87,
                            ),
                          ),
                          Text(product['unit'], style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                );
              }
            ),
            if (i < products.length - 1) 
              Divider(height: 1, color: Colors.grey.shade100, indent: 20, endIndent: 20),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isar = Provider.of<Isar>(context);
    final monthStr = DateFormat('MMM, yyyy', 'id_ID').format(_selectedMonthYear);

    return Scaffold(
      backgroundColor: Colors.white, // background murni putih ffffff
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top Title
              const SizedBox(height: 10),
              const Text('Laporan Keuangan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 24),

              // Header Row (Logo & Calendar)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo AL RAHMAN Mimic
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade700,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                            bottomRight: Radius.circular(4),
                            bottomLeft: Radius.circular(4),
                          ),
                        ),
                        child: const Icon(Icons.shopping_bag, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AL RAHMAN', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.5)),
                          Text('— TOKO GROSIR SEMBAKO —', style: TextStyle(color: Colors.blue.shade300, fontSize: 8, letterSpacing: 0.5, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  // Calendar Button with Text
                  GestureDetector(
                    onTap: _showMonthYearPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month, color: Colors.blue.shade700, size: 16),
                          const SizedBox(width: 6),
                          Text('($monthStr)', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),

              FutureBuilder<Map<String, dynamic>>(
                future: _getAllChartData(isar),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox(height: 400, child: Center(child: CircularProgressIndicator()));
                  }
                  final data = snapshot.data!;
                  final days = data['daysInMonth'] as int;

                  return Column(
                    children: [
                      // Graph 1: Penghasilan / Keuntungan
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 4)),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Select Option Dropdown for Graph 1
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _graph1Type,
                                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black87),
                                  isDense: true,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        _graph1Type = newValue;
                                      });
                                    }
                                  },
                                  items: const [
                                    DropdownMenuItem(value: 'penghasilan', child: Text('Total Penghasilan /hari')),
                                    DropdownMenuItem(value: 'keuntungan', child: Text('Total Keuntungan /hari')),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Graph
                            _buildLineChart(
                              spots: data['g1Spots'], 
                              minY: data['g1MinY'], 
                              maxY: data['g1MaxY'], 
                              daysInMonth: days, 
                              isCurrency: true
                            ),
                            const SizedBox(height: 12),
                            Center(child: Text('Tanggal', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey.shade500))),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),

                      // Graph 2: Total Transaksi
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 4)),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Transaksi /hari', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 24),
                            
                            // Graph
                            _buildLineChart(
                              spots: data['g2Spots'], 
                              minY: 0, 
                              maxY: data['g2MaxY'], 
                              daysInMonth: days, 
                              isCurrency: false
                            ),
                            const SizedBox(height: 12),
                            Center(child: Text('Tanggal', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey.shade500))),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
              
              const SizedBox(height: 24),

              // Products Ranking
              FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
                future: _getProductRankings(isar),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final best = snapshot.data!['best']!;
                  final worst = snapshot.data!['worst']!;

                  return Column(
                    children: [
                      _buildProductList('5 Barang Terlaris', best, false),
                      _buildProductList('5 Barang Kurang Laris', worst, true),
                    ],
                  );
                },
              ),
              const SizedBox(height: 60),

              // Tombol Logout di paling bawah
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('Keluar Akun?', style: TextStyle(fontWeight: FontWeight.bold)),
                        content: const Text('Apakah Anda yakin ingin keluar dari akun ini?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              await AuthService.logout();
                              if (!context.mounted) return;
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (_) => const LoginScreen()),
                                (route) => false,
                              );
                            },
                            child: const Text('Keluar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: Icon(Icons.logout, color: Colors.red.shade400, size: 18),
                  label: Text('Keluar Akun', style: TextStyle(color: Colors.red.shade400, fontSize: 13)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
