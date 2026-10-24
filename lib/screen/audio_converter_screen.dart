import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'dart:convert';
import 'dart:io';

class AudioLosslessScreen extends StatefulWidget {
  const AudioLosslessScreen({super.key});
  @override
  State<AudioLosslessScreen> createState() => _AudioLosslessScreenState();
}

class _AudioLosslessScreenState extends State<AudioLosslessScreen> {
  List<String> _selectedFlacPaths = [];
  String? _outputFolderPath;
  bool _isConverting = false;
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();

  Future<void> _pickFlacFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['flac'],
      allowMultiple: true,
    );

    if (result != null && result.paths.isNotEmpty) {
      setState(() {
        _selectedFlacPaths = result.paths.whereType<String>().toList();
        if (_outputFolderPath == null && _selectedFlacPaths.isNotEmpty) {
          _outputFolderPath = p.dirname(_selectedFlacPaths.first);
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
      if (_scrollController.hasClients) _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _startBatchLosslessConversion() async {
    if (_selectedFlacPaths.isEmpty || _outputFolderPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn bài hát và thư mục!')));
      return;
    }

    setState(() {
      _isConverting = true;
      _logs.clear();
    });

    _addLog('🚀 BẮT ĐẦU CHUỖI TIẾN TRÌNH ÂM THANH (${_selectedFlacPaths.length} BÀI HÁT)');

    for (int i = 0; i < _selectedFlacPaths.length; i++) {
      if (!mounted) break;

      final inputPath = _selectedFlacPaths[i];
      final baseName = p.basenameWithoutExtension(inputPath);
      final outputPath = p.join(_outputFolderPath!, '${baseName}_ALAC.m4a');

      _addLog('\n========================================');
      _addLog('▶ ĐANG XỬ LÝ [${i + 1}/${_selectedFlacPaths.length}]: $baseName');

      try {
        final process = await Process.start('ffmpeg', [
          '-i', inputPath,
          '-c:a', 'alac', // Decode Audio sang ALAC
          '-c:v', 'copy', // BẮT BUỘC: Giữ nguyên ảnh bìa Album, không convert thành Video H264
          '-v', 'info',
          '-y',
          outputPath
        ]);

        process.stderr
            .transform(const Utf8Decoder(allowMalformed: true))
            .transform(const LineSplitter())
            .listen((data) => _addLog(data));

        final exitCode = await process.exitCode;
        if (exitCode == 0) {
          _addLog('✅ XONG: ${baseName}_ALAC.m4a');
        } else {
          _addLog('❌ LỖI (Code $exitCode): Bỏ qua bài hát này.');
        }
      } catch (e) {
        _addLog('❌ LỖI HỆ THỐNG TRÊN BÀI NÀY: $e');
      }
    }

    if (mounted) {
      setState(() => _isConverting = false);
      _addLog('\n🎉 ĐÃ HOÀN TẤT TOÀN BỘ DANH SÁCH!');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Batch FLAC to ALAC', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
              child: ListTile(
                leading: const Icon(Icons.library_music, color: Colors.deepPurple),
                title: Text(
                  _selectedFlacPaths.isEmpty ? 'Chưa chọn bài hát FLAC' : 'Đã chọn ${_selectedFlacPaths.length} bài hát',
                  style: TextStyle(fontWeight: FontWeight.bold, color: _selectedFlacPaths.isEmpty ? Colors.red : Colors.black),
                ),
                trailing: ElevatedButton.icon(
                  onPressed: _isConverting ? null : _pickFlacFiles,
                  icon: const Icon(Icons.music_note),
                  label: const Text('Thêm FLAC'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
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
                            const Text('Thư mục lưu bài hát (.m4a)', style: TextStyle(fontSize: 13, color: Colors.black87)),
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
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isConverting ? null : _startBatchLosslessConversion,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              icon: _isConverting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.apple),
              label: Text(_isConverting ? 'Đang giải mã và đóng gói...' : 'Convert Hàng Loạt (M4A)'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(8)),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _logs.length,
                  itemBuilder: (context, index) => Text(_logs[index], style: const TextStyle(color: Colors.greenAccent, fontFamily: 'Consolas', fontSize: 12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}