import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../sync_service.dart';
import '../auth_service.dart';
import 'pos_screen.dart';
import 'products_screen.dart';
import 'transactions_screen.dart';
import 'orders_screen.dart';
import 'reports_screen.dart';
import 'package:isar/isar.dart';
import '../models/order.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const ProductsScreen(),
    const TransactionsScreen(),
    const SizedBox.shrink(), // Placeholder for SCAN button
    const OrdersScreen(),
    const ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isar = context.read<Isar>();

    return Scaffold(
      body: _screens[_currentIndex],
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        margin: const EdgeInsets.only(top: 10),
        height: 70,
        width: 70,
        child: FloatingActionButton(
          onPressed: () {
            // Open POS Kasir
            Navigator.push(context, MaterialPageRoute(builder: (context) => const PosScreen()));
          },
          backgroundColor: const Color(0xFF0D47A1), // Deep blue color
          elevation: 4,
          shape: const CircleBorder(),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_scanner, color: Colors.white, size: 28),
              Text('SCAN', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _buildNavItem(icon: Icons.grid_view, label: 'Barang', index: 0),
              _buildNavItem(icon: Icons.receipt_long, label: 'Transaksi', index: 1),
              const SizedBox(width: 40), // Spacer for the FAB
              
              // Orders with Badge
              StreamBuilder<List<OnlineOrder>>(
                stream: isar.onlineOrders.filter().statusEqualTo('pending').watch(fireImmediately: true),
                builder: (context, snapshot) {
                  final pendingCount = snapshot.data?.length ?? 0;
                  return _buildNavItem(
                    icon: Icons.edit_document, 
                    label: 'Pesanan', 
                    index: 3,
                    badgeCount: pendingCount
                  );
                }
              ),
              
              _buildNavItem(icon: Icons.show_chart, label: 'Keuangan', index: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required String label, required int index, int badgeCount = 0}) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? const Color(0xFF0D47A1) : Colors.grey;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 26),
                if (badgeCount > 0)
                  Positioned(
                    top: -5,
                    right: -10,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: Text(
                        badgeCount > 99 ? '99+' : badgeCount.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

