import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

class VideoConverterScreen extends StatefulWidget {
  const VideoConverterScreen({super.key});

  @override
  State<VideoConverterScreen> createState() => _VideoConverterScreenState();
}

class _VideoConverterScreenState extends State<VideoConverterScreen> {
  List<String> _selectedVideoPaths = []; 
  String? _outputFolderPath;
  bool _isConverting = false;
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();

  Future<void> _pickVideos() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: true, 
    );

    if (result != null && result.paths.isNotEmpty) {
      setState(() {
        _selectedVideoPaths = result.paths.whereType<String>().toList();
        if (_outputFolderPath == null && _selectedVideoPaths.isNotEmpty) {
          _outputFolderPath = p.dirname(_selectedVideoPaths.first);
        }
      });
    }
  }

  Future<void> _pickOutputFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) setState(() => _outputFolderPath = selectedDirectory);
  }

  Future<void> _openFolder(String path) async {
    if (await Directory(path).exists()) {
      await Process.run('explorer.exe', [path]);
    } else {
      _addLog('❌ Thư mục không tồn tại: $path');
    }
  }

  void _addLog(String log) {
    if (!mounted) return;
    setState(() => _logs.add(log));
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _startBatchConversion() async {
    if (_selectedVideoPaths.isEmpty || _outputFolderPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn video và thư mục lưu trữ!')),
      );
      return;
    }

    setState(() {
      _isConverting = true;
      _logs.clear();
    });

    _addLog('🚀 BẮT ĐẦU CHUỖI TIẾN TRÌNH (${_selectedVideoPaths.length} FILE)');
    
    for (int i = 0; i < _selectedVideoPaths.length; i++) {
      if (!mounted) break; 

      final inputPath = _selectedVideoPaths[i];
      final baseName = p.basenameWithoutExtension(inputPath);
      final ext = p.extension(inputPath);
      final outputPath = p.join(_outputFolderPath!, '${baseName}_premiere$ext');

      _addLog('\n========================================');
      _addLog('▶ ĐANG XỬ LÝ [${i + 1}/${_selectedVideoPaths.length}]: $baseName');

      try {
        final process = await Process.start('ffmpeg', [
          '-i', inputPath,
          '-c:v', 'libx264',
          '-crf', '18',
          '-c:a', 'copy',
          '-y',
          outputPath,
        ]);

        process.stderr
            .transform(const Utf8Decoder(allowMalformed: true))
            .transform(const LineSplitter())
            .listen((data) {
          _addLog(data); 
        });

        final exitCode = await process.exitCode;
        if (exitCode == 0) {
          _addLog('✅ XONG: ${baseName}_premiere$ext');
        } else {
          _addLog('❌ LỖI CONVERT (Code $exitCode): Bỏ qua file này.');
        }
      } catch (e) {
        _addLog('❌ LỖI HỆ THỐNG TRÊN FILE NÀY: $e');
      }
    }

    if (mounted) {
      setState(() => _isConverting = false);
      _addLog('\n🎉 ĐÃ HOÀN TẤT TOÀN BỘ DANH SÁCH!');
      _addLog('📁 Mở thư mục lưu trữ để xem kết quả.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Batch Video Converter', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
              child: ListTile(
                leading: const Icon(Icons.video_collection, color: Colors.blue),
                title: Text(
                  _selectedVideoPaths.isEmpty ? 'Chưa chọn video gốc' : 'Đã chọn ${_selectedVideoPaths.length} video',
                  style: TextStyle(fontWeight: FontWeight.bold, color: _selectedVideoPaths.isEmpty ? Colors.red : Colors.black),
                ),
                subtitle: const Text('Nhấn chọn nhiều file cùng lúc bằng cách bôi đen hoặc Ctrl+Click'),
                trailing: ElevatedButton.icon(
                  onPressed: _isConverting ? null : _pickVideos,
                  icon: const Icon(Icons.library_add),
                  label: const Text('Thêm Video'),
                ),
              ),
            ),
            const SizedBox(height: 12),

            _buildFolderSelector(),
            const SizedBox(height: 16),

            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isConverting ? null : _startBatchConversion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isConverting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.bolt),
                label: Text(
                  _isConverting ? 'Hệ thống đang chạy ngầm...' : 'Tiến Hành Convert Hàng Loạt',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text('Terminal Output:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(8)),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    return Text(_logs[index], style: const TextStyle(color: Colors.greenAccent, fontFamily: 'Consolas', fontSize: 12));
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderSelector() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF3F4F8), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.folder_special, color: Colors.amber, size: 28),
              onPressed: _outputFolderPath != null ? () => _openFolder(_outputFolderPath!) : null,
            ),
            Expanded(
              child: InkWell(
                onTap: _outputFolderPath != null ? () => _openFolder(_outputFolderPath!) : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Thư mục lưu trữ (Click để mở)', style: TextStyle(fontSize: 13, color: Colors.black87)),
                    const SizedBox(height: 2),
                    Text(
                      _outputFolderPath ?? 'Chưa chọn thư mục',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _outputFolderPath == null ? Colors.red : Colors.blue.shade900),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            OutlinedButton(
              onPressed: _isConverting ? null : _pickOutputFolder,
              style: OutlinedButton.styleFrom(backgroundColor: Colors.white, side: BorderSide(color: Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              child: const Text('Thay đổi', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      ),
    );
  }
}