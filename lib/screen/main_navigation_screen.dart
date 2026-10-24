
import 'package:flutter/material.dart';
// Lưu ý: Cần add package 'file_picker' và 'path' vào pubspec.yaml
import 'package:qr_gen_app/screen/qr_screen.dart';
import 'package:qr_gen_app/screen/video_coverter_sceen.dart';
import 'package:qr_gen_app/screen/video_downloader_screen.dart';
import 'package:qr_gen_app/screen/audio_converter_screen.dart';
import 'package:qr_gen_app/screen/network_scanner_screen.dart'; 
import 'package:qr_gen_app/screen/order_calculator_screen.dart';
// Thêm import cho NetworkScannerScreen
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  // Danh sách các màn hình chức năng
  final List<Widget> _screens = const [
    QRGeneratorScreen(),
    VideoConverterScreen(),
    VideoDownloaderScreen(),
    AudioLosslessScreen(),
    NetworkScannerScreen(),
    OrderCalculatorScreen() // Thêm màn hình NetworkScanner vào danh sách
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.qr_code_2),
            label: 'Tạo QR',
          ),
          NavigationDestination(
            icon: Icon(Icons.movie_creation),
            label: 'Convert Video',
          ),
          NavigationDestination(
            icon: Icon(Icons.download),
            label: 'Tải Facebook',
          ),
          NavigationDestination(
            icon: Icon(Icons.audiotrack),
            label: 'Convert FLAC -> ALAC',
          ),
           NavigationDestination(
            icon: Icon(Icons.radar), // Icon Radar cho công cụ quét
            label: 'Quét LAN',
          ),
           NavigationDestination(
            icon: Icon(Icons.calculate), // Icon máy tính
            label: 'Giá Order',
          ),
        ],
      ),
    );
  }
}