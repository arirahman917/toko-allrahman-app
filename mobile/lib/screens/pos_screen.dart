import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:isar/isar.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import 'pos_manual_input_screen.dart';
import 'pos_recap_screen.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  List<CartItem> _cart = [];
  bool _isFlashOn = false;

  void _handleBarcode(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null) {
        // Pause scanner to avoid multiple reads
        _scannerController.pause();
        
        final isar = context.read<Isar>();
        final product = await isar.products.filter().isDeletedEqualTo(false).barcodeEqualTo(code).findFirst();
        
        if (product != null) {
          if (product.stock <= 0) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${product.name} stok habis, tidak bisa masuk keranjang'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } else {
            setState(() {
              final existing = _cart.where((e) => e.product.id == product.id).toList();
              if (existing.isNotEmpty) {
                if (existing.first.quantity < product.stock) {
                  existing.first.quantity += 1;
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${product.name} sudah mencapai batas stok'), backgroundColor: Colors.orange),
                  );
                }
              } else {
                _cart.add(CartItem(product: product, quantity: 1));
              }
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${product.name} masuk keranjang'), duration: const Duration(seconds: 1)),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Barcode $code tidak ditemukan'), backgroundColor: Colors.red),
            );
          }
        }
        
        // Resume scanner after a short delay
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          _scannerController.start();
        }
      }
    }
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _goToManualInput() async {
    // Pause scanner when navigating away
    _scannerController.pause();
    
    final updatedCart = await Navigator.push<List<CartItem>>(
      context,
      MaterialPageRoute(
        builder: (_) => PosManualInputScreen(initialCart: _cart),
      ),
    );

    if (updatedCart != null) {
      setState(() {
        _cart = updatedCart;
      });
    }
    
    // Resume scanner when back
    if (mounted) {
      _scannerController.start();
    }
  }

  void _goToRecap() async {
    _scannerController.pause();
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PosRecapScreen(cart: _cart),
      ),
    );

    // If transaction succeeds, the recap screen can return 'success'
    // and we clear the cart.
    if (result == true) {
      setState(() {
        _cart.clear();
      });
    }

    if (mounted) {
      _scannerController.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleBarcode,
          ),
          
          // Scanner Overlay (Dark background with clear center cutout)
          ColorFiltered(
            colorFilter: const ColorFilter.mode(
              Colors.black54,
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  child: Align(
                    alignment: const Alignment(0, -0.15),
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        color: Colors.black, // This creates the cutout
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Scanner Border and Corners (Visual only)
          Align(
            alignment: const Alignment(0, -0.15),
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          // Top Action Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text('Scan', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off, color: Colors.white, size: 28),
                    onPressed: () {
                      _scannerController.toggleTorch();
                      setState(() {
                        _isFlashOn = !_isFlashOn;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // Bottom Controls (Input Manual & Checklist)
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _goToManualInput,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.inventory_2_outlined, color: Colors.black87),
                        SizedBox(width: 8),
                        Text('Input Manual', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: _goToRecap,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 40),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
