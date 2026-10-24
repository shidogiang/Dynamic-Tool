import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Class chứa toàn bộ dữ liệu kết quả để render
class OrderResult {
  final double baseVND;
  final double feeVND;
  final double shipVND;
  final double bubbleWrapVND;
  final double profitVND;
  final double totalVND;
  final double shopeeVND;

  OrderResult({
    this.baseVND = 0.0,
    this.feeVND = 0.0,
    this.shipVND = 0.0,
    this.bubbleWrapVND = 0.0,
    this.profitVND = 0.0,
    this.totalVND = 0.0,
    this.shopeeVND = 0.0,
  });
}

class OrderCalculatorScreen extends StatefulWidget {
  const OrderCalculatorScreen({super.key});

  @override
  State<OrderCalculatorScreen> createState() => _OrderCalculatorScreenState();
}

class _OrderCalculatorScreenState extends State<OrderCalculatorScreen> {
  bool _isLoadingRates = true;
  Map<String, double> _rates = {
    'USD': 25400.0, 
    'CNY': 3550.0,  
  };

  String _selectedCurrency = 'CNY';
  
  // Controllers cho các ô nhập liệu
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _feeController = TextEditingController(text: '3.2');
  final TextEditingController _weightController = TextEditingController();
  
  // ĐÃ FIX: Chuyển lợi nhuận thành Controller để gõ được số tùy ý
  final TextEditingController _profitController = TextEditingController(text: '100000');
  final List<double> _profitOptions = [70000.0, 100000.0, 200000.0, 400000.0, 500000.0];

  // Option bọt khí
  bool _isBubbleWrap = false;

  final double _shipRatePerKg = 30000.0;

  // Trạm phát sóng kết quả
  final ValueNotifier<OrderResult> _resultNotifier = ValueNotifier(OrderResult());

  @override
  void initState() {
    super.initState();
    _fetchLiveRates();
    _calculate(); // Tính lần đầu để khởi tạo giá trị
  }

  @override
  void dispose() {
    _amountController.dispose();
    _feeController.dispose();
    _weightController.dispose();
    _profitController.dispose();
    _resultNotifier.dispose(); 
    super.dispose();
  }

  Future<void> _fetchLiveRates() async {
    try {
      final client = HttpClient();
      
      final usdReq = await client.getUrl(Uri.parse('https://api.exchangerate-api.com/v4/latest/USD'));
      final usdRes = await usdReq.close();
      final usdData = jsonDecode(await usdRes.transform(utf8.decoder).join());
      
      final cnyReq = await client.getUrl(Uri.parse('https://api.exchangerate-api.com/v4/latest/CNY'));
      final cnyRes = await cnyReq.close();
      final cnyData = jsonDecode(await cnyRes.transform(utf8.decoder).join());

      if (mounted) {
        setState(() {
          _rates['USD'] = (usdData['rates']['VND'] as num).toDouble();
          _rates['CNY'] = (cnyData['rates']['VND'] as num).toDouble();
          _isLoadingRates = false;
        });
        _calculate(); 
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRates = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể tải tỉ giá mới. Đang dùng dự phòng!')),
        );
      }
    }
  }

  // Hàm tính toán mọi thứ ở đây (ách tắc được giải phóng khỏi build)
  void _calculate() {
    double amount = double.tryParse(_amountController.text) ?? 0.0;
    double currentRate = _rates[_selectedCurrency] ?? 0.0;
    double feePercent = double.tryParse(_feeController.text) ?? 0.0;
    double weight = double.tryParse(_weightController.text) ?? 0.0;
    double profit = double.tryParse(_profitController.text) ?? 0.0;

    double baseVND = amount * currentRate;
    double feeVND = baseVND * (feePercent / 100);
    double shipVND = weight * _shipRatePerKg;
    
    // Logic tính phí bọt khí (Làm tròn cân nặng lên, tính bằng tỉ giá Tệ)
    double bubbleWrapVND = 0.0;
    if (_isBubbleWrap && weight > 0) {
      double calcWeight = weight.ceilToDouble(); // Ví dụ: 1.5 -> 2.0
      double bubbleFeeCNY = 10.0 + (calcWeight > 1.0 ? (calcWeight - 1.0) * 1.0 : 0.0);
      double cnyRate = _rates['CNY'] ?? 3550.0; // Luôn dùng Tệ để tính phí đóng gói TQ
      bubbleWrapVND = bubbleFeeCNY * cnyRate;
    }

    // A = Gốc + Phí + Lợi Nhuận + Ship + Bọt Khí
    double totalVND = baseVND + feeVND + profit + shipVND + bubbleWrapVND;
    
    // Giá Shopee = A/0.72
    double shopeeVND = totalVND/0.72;

    // Phát sóng kết quả mới
    _resultNotifier.value = OrderResult(
      baseVND: baseVND,
      feeVND: feeVND,
      shipVND: shipVND,
      bubbleWrapVND: bubbleWrapVND,
      profitVND: profit,
      totalVND: totalVND,
      shopeeVND: shopeeVND,
    );
  }

  String formatVND(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), 
      (Match m) => '${m[1]}.'
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo Giá Order', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoadingRates = true);
              _fetchLiveRates();
            },
          )
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildRateCard(),
              const SizedBox(height: 16),

              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              value: _selectedCurrency,
                              decoration: const InputDecoration(labelText: 'Ngoại tệ', border: OutlineInputBorder()),
                              items: ['CNY', 'USD'].map((String curr) {
                                return DropdownMenuItem(
                                  value: curr,
                                  child: Text(curr == 'CNY' ? '🇨🇳 Tệ' : '🇺🇸 Đô', style: const TextStyle(fontWeight: FontWeight.bold)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() => _selectedCurrency = val!);
                                _calculate(); 
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 5,
                            child: TextFormField(
                              controller: _amountController,
                              keyboardType: TextInputType.text,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                              decoration: const InputDecoration(labelText: 'Số tiền gốc', border: OutlineInputBorder(), prefixIcon: Icon(Icons.payments)),
                              onChanged: (val) => _calculate(), 
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _feeController,
                              keyboardType: TextInputType.text,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                              decoration: const InputDecoration(labelText: 'Phí mặc định', suffixText: '%', border: OutlineInputBorder()),
                              onChanged: (val) => _calculate(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 5,
                            child: TextFormField(
                              controller: _profitController,
                              keyboardType: TextInputType.text,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                              decoration: InputDecoration(
                                labelText: 'Lợi nhuận (VND)', 
                                border: const OutlineInputBorder(),
                                // Menu thả xuống để chọn nhanh
                                suffixIcon: PopupMenuButton<double>(
                                  icon: const Icon(Icons.arrow_drop_down_circle, color: Colors.blueAccent),
                                  tooltip: 'Chọn nhanh mức công',
                                  onSelected: (val) {
                                    _profitController.text = val.toStringAsFixed(0);
                                    _calculate();
                                  },
                                  itemBuilder: (context) => _profitOptions.map((p) => PopupMenuItem(
                                    value: p,
                                    child: Text('+ ${formatVND(p)} đ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                  )).toList(),
                                ),
                              ),
                              onChanged: (val) => _calculate(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: TextFormField(
                              controller: _weightController,
                              keyboardType: TextInputType.text,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                              decoration: const InputDecoration(labelText: 'Cân nặng (kg)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.scale)),
                              onChanged: (val) => _calculate(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.blue.shade200)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Phí Ship VN (30k/kg)', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                                  ValueListenableBuilder<OrderResult>(
                                    valueListenable: _resultNotifier,
                                    builder: (context, result, child) {
                                      return Text(
                                        '+ ${formatVND(result.shipVND)} đ',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                                      );
                                    }
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Nút tick Bọc Bọt Khí
                      CheckboxListTile(
                        title: const Text('Bọc bọt khí kho TQ (10 tệ/kg đầu, 1 tệ/kg sau)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                        value: _isBubbleWrap,
                        onChanged: (val) {
                          // Phải dùng setState để tick/bỏ tick có hiệu ứng
                          setState(() {
                            _isBubbleWrap = val ?? false;
                            _calculate();
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // KHUNG HIỂN THỊ KẾT QUẢ ĐÃ TỐI ƯU HIỆU SUẤT
              ValueListenableBuilder<OrderResult>(
                valueListenable: _resultNotifier,
                builder: (context, result, child) {
                  return Card(
                    elevation: 4,
                    color: const Color(0xFF1E1E1E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const Text('GIÁ ORDER TRỰC TIẾP (A)', style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 1.2)),
                          const SizedBox(height: 4),
                          Text(
                            '${formatVND(result.totalVND)} đ',
                            style: const TextStyle(color: Colors.amberAccent, fontSize: 32, fontWeight: FontWeight.w900),
                          ),
                          
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Column(
                              children: [
                                const Text('GIÁ BÁN TRÊN SHOPEE (+72%)', style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 1.2)),
                                const SizedBox(height: 4),
                                Text(
                                  '${formatVND(result.shopeeVND)} đ',
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 34, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),

                          const Divider(color: Colors.white24, height: 28),
                          
                          _buildDetailRow('Giá sản phẩm:', '${formatVND(result.baseVND)} đ'),
                          _buildDetailRow('Phí dịch vụ (${_feeController.text}%):', '+ ${formatVND(result.feeVND)} đ'),
                          _buildDetailRow('Tiền công:', '+ ${formatVND(result.profitVND)} đ'),
                          _buildDetailRow('Phí vận chuyển:', '+ ${formatVND(result.shipVND)} đ'),
                          if (result.bubbleWrapVND > 0)
                            _buildDetailRow('Bọc bọt khí:', '+ ${formatVND(result.bubbleWrapVND)} đ'),
                        ],
                      ),
                    ),
                  );
                },
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRateCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.currency_exchange, color: Colors.green),
              const SizedBox(width: 8),
              const Text('Tỉ giá hiện tại:', style: TextStyle(fontWeight: FontWeight.bold)),
              if (_isLoadingRates) const Padding(padding: EdgeInsets.only(left: 8.0), child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))),
            ],
          ),
          Text(
            '1 $_selectedCurrency = ${formatVND(_rates[_selectedCurrency]!)} đ',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}