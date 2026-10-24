import 'package:flutter/material.dart';
import 'dart:io'; 
import 'package:lan_scanner/lan_scanner.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class NetworkScannerScreen extends StatefulWidget {
  const NetworkScannerScreen({super.key});

  @override
  State<NetworkScannerScreen> createState() => _NetworkScannerScreenState();
}

class _NetworkScannerScreenState extends State<NetworkScannerScreen> {
  bool _isScanning = false;
  String? _wifiIP;
  String? _subnet;
  double _progress = 0.0;
  final List<Host> _foundDevices = [];

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndGetIP();
  }

  Future<void> _checkPermissionsAndGetIP() async {
    // Yêu cầu quyền vị trí (Bắt buộc để lấy IP trên Android)
    var status = await Permission.location.request();
    if (status.isGranted) {
      await _getWifiIP();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cần cấp quyền vị trí để lấy IP Wi-Fi!')),
        );
      }
    }
  }

  Future<void> _getWifiIP() async {
    final info = NetworkInfo();
    final ip = await info.getWifiIP();
    
    if (mounted) {
      setState(() {
        _wifiIP = ip;
        if (ip != null) {
          _subnet = ipToCSubnet(ip);
        }
      });
    }
  }

  Future<void> _startScan() async {
    if (_subnet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không xác định được mạng Wi-Fi. Hãy kết nối Wi-Fi!')),
      );
      return;
    }

    setState(() {
      _isScanning = true;
      _progress = 0.0;
      _foundDevices.clear();
    });

    final scanner = LanScanner();
    final stream = scanner.icmpScan(
      _subnet!,
      scanThreads: 20, // Chạy 20 luồng ping cùng lúc để tăng tốc
      progressCallback: (progress) {
        if (mounted) {
          setState(() {
            _progress = progress;
          });
        }
      },
    );

    stream.listen((Host host) {
      // Đã fix: Bỏ && host.exists vì Stream chỉ trả về những Host có phản hồi
      if (mounted) {
        setState(() {
          _foundDevices.add(host);
        });
      }
    }, onDone: () {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _progress = 1.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã quét xong! Tìm thấy ${_foundDevices.length} thiết bị.')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Scanner', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thẻ hiển thị thông tin mạng hiện tại
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.wifi, size: 40, color: Colors.blue),
                    const SizedBox(height: 8),
                    Text(
                      'IP của bạn: ${_wifiIP ?? "Đang tải..."}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Dải quét: ${_subnet ?? "Chưa rõ"}.*',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Nút Quét
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: (_isScanning || _subnet == null) ? null : _startScan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isScanning 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.radar),
                label: Text(
                  _isScanning ? 'Đang quét mạng (${(_progress * 100).toStringAsFixed(0)}%)...' : 'Bắt Đầu Quét Mạng LAN',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Thanh tiến trình
            if (_isScanning) ...[
              LinearProgressIndicator(value: _progress, backgroundColor: Colors.grey.shade300, color: Colors.teal),
              const SizedBox(height: 16),
            ],

            // Danh sách thiết bị tìm thấy
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _foundDevices.isEmpty
                    ? Center(
                        child: Text(
                          _isScanning ? 'Đang tìm kiếm thiết bị...' : 'Chưa có dữ liệu.\nNhấn nút Quét để bắt đầu.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _foundDevices.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final device = _foundDevices[index];
                          
                          // Lấy địa chỉ IP và thời gian Ping theo chuẩn của bản cập nhật mới
                          final ipAddress = device.internetAddress.address;
                          final pingMs = device.pingTime?.inMilliseconds ?? "?";                          
                          // Phân biệt thiết bị của mình và thiết bị khác
                          final isMyDevice = ipAddress == _wifiIP;

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isMyDevice ? Colors.blue.shade100 : Colors.teal.shade100,
                              child: Icon(
                                isMyDevice ? Icons.smartphone : Icons.devices,
                                color: isMyDevice ? Colors.blue : Colors.teal,
                              ),
                            ),
                            title: Text(
                              ipAddress,
                              style: TextStyle(
                                fontWeight: isMyDevice ? FontWeight.bold : FontWeight.normal,
                                color: isMyDevice ? Colors.blue.shade800 : Colors.black87,
                              ),
                            ),
                            subtitle: Text('Độ trễ: ${pingMs}ms'),
                            trailing: isMyDevice ? const Chip(label: Text('Máy này', style: TextStyle(fontSize: 10))) : null,
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}