import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class VideoDownloaderScreen extends StatefulWidget {
  const VideoDownloaderScreen({super.key});

  @override
  State<VideoDownloaderScreen> createState() => _VideoDownloaderScreenState();
}

class _VideoDownloaderScreenState extends State<VideoDownloaderScreen> {
  final TextEditingController _linkController = TextEditingController();
  String? _saveDirectory;
  bool _isDownloading = false;
  
  // Quản lý định dạng tải xuống
  String _selectedFormat = 'Video (MP4)'; 
  final List<String> _formatOptions = ['Video (MP4)', 'Audio (MP3)']; 

  // Quản lý Log và cuộn tự động
  final List<String> _processLogs = [];
  final ScrollController _scrollController = ScrollController();

  Future<void> _pickDirectory() async {
    String? selected = await FilePicker.platform.getDirectoryPath();
    if (selected != null) {
      setState(() => _saveDirectory = selected);
    }
  }

  Future<void> _openFolder(String path) async {
    if (await Directory(path).exists()) {
      await Process.run('explorer.exe', [path]);
    } else {
      _addLog('❌ Thư mục không tồn tại: $path');
    }
  }

  void _addLog(String log) {
    if(!mounted) return;
    setState(() => _processLogs.add(log));
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  Future<void> _downloadVideo({required bool isYoutube}) async {
    final link = _linkController.text.trim();
    if (link.isEmpty || _saveDirectory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng dán link và chọn thư mục lưu trữ!')),
      );
      return;
    }

    setState(() { 
      _isDownloading = true; 
      _processLogs.clear(); 
    });
    
    final formatIcon = _selectedFormat == 'Audio (MP3)' ? '🎵' : '🎬';
    final platform = isYoutube ? 'YouTube' : 'Facebook';
    _addLog('🚀 Đang chuẩn bị tải $formatIcon từ $platform...');

    try {
      List<String> args;

      if (_selectedFormat == 'Audio (MP3)') {
        // Lệnh tách âm thanh MP3 (Áp dụng chung, tự động gọi FFmpeg ngầm)
        args = ['-x', '--audio-format', 'mp3', '--audio-quality', '0', '--restrict-filenames', '-o', '%(title).50s.%(ext)s', link];
      } else {
        // Lệnh tải Video MP4
        args = isYoutube
            ? ['-f', 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best', '--restrict-filenames', '-o', '%(title).50s.%(ext)s', link]
            : ['--restrict-filenames', '-o', '%(title).50s.%(ext)s', link];
      }

      final process = await Process.start('yt-dlp', args, workingDirectory: _saveDirectory);
      
      // Lắng nghe dữ liệu trả về từ terminal
      process.stdout.transform(const Utf8Decoder(allowMalformed: true)).transform(const LineSplitter()).listen((data) => _addLog(data));
      process.stderr.transform(const Utf8Decoder(allowMalformed: true)).transform(const LineSplitter()).listen((data) => _addLog(data));

      final exitCode = await process.exitCode;
      if (exitCode == 0) {
        _addLog('✅ XONG! Đã lưu file vào thư mục.');
      } else {
        _addLog('❌ LỖI (Code $exitCode). Hãy thử kiểm tra lại link.');
      }
    } catch (e) {
      _addLog('❌ LỖI HỆ THỐNG: $e');
      _addLog('Vui lòng đảm bảo yt-dlp và ffmpeg đã được cấu hình trong PATH.');
    } finally {
      if(mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đa Tải Trọng (FB & YT)', style: TextStyle(fontWeight: FontWeight.bold)), 
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ô nhập Link
            TextField(
              controller: _linkController,
              decoration: InputDecoration(
                labelText: 'Dán link video Facebook hoặc YouTube...', 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), 
                prefixIcon: const Icon(Icons.link, color: Colors.blueAccent),
                filled: true,
                fillColor: Colors.blue.shade50.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 12),
            
            // Menu thả xuống (Dropdown) chọn định dạng
            DropdownButtonFormField<String>(
              value: _selectedFormat,
              decoration: InputDecoration(
                labelText: 'Chọn định dạng tải về',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.settings_input_component, color: Colors.deepPurple),
              ),
              items: _formatOptions.map((String format) {
                return DropdownMenuItem<String>(
                  value: format,
                  child: Text(format, style: const TextStyle(fontWeight: FontWeight.bold)),
                );
              }).toList(),
              onChanged: _isDownloading ? null : (String? newValue) {
                setState(() {
                  _selectedFormat = newValue!;
                });
              },
            ),
            const SizedBox(height: 16),

            // Nơi hiển thị / Chọn thư mục lưu
            _buildFolderSelector(),
            const SizedBox(height: 20),

            // Cụm 2 nút bấm Tải Facebook và YouTube
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isDownloading ? null : () => _downloadVideo(isYoutube: false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent, 
                      foregroundColor: Colors.white, 
                      padding: const EdgeInsets.symmetric(vertical: 16), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.facebook),
                    label: Text(_isDownloading ? 'Đang tải...' : 'Tải Facebook', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isDownloading ? null : () => _downloadVideo(isYoutube: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent, 
                      foregroundColor: Colors.white, 
                      padding: const EdgeInsets.symmetric(vertical: 16), 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.play_circle_filled),
                    label: Text(_isDownloading ? 'Đang tải...' : 'Tải YouTube', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Khung hiển thị Log Terminal
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E), 
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))
                  ]
                ),
                child: _processLogs.isEmpty 
                  ? Center(child: Text('Terminal Output sẽ hiển thị ở đây...', style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic)))
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _processLogs.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text(
                          _processLogs[index], 
                          style: const TextStyle(color: Colors.cyanAccent, fontFamily: 'Consolas', fontSize: 12),
                        ),
                      ),
                    ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFolderSelector() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F8), 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: Colors.grey.shade300)
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.folder_special, color: Colors.amber, size: 30),
              onPressed: _saveDirectory != null ? () => _openFolder(_saveDirectory!) : null,
              tooltip: 'Mở thư mục này',
            ),
            Expanded(
              child: InkWell(
                onTap: _saveDirectory != null ? () => _openFolder(_saveDirectory!) : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Thư mục lưu trữ (Click để mở)', style: TextStyle(fontSize: 13, color: Colors.black87)),
                    const SizedBox(height: 2),
                    Text(
                      _saveDirectory ?? 'Chưa chọn thư mục',
                      style: TextStyle(
                        fontSize: 14, 
                        fontWeight: FontWeight.bold, 
                        color: _saveDirectory == null ? Colors.red : Colors.blue.shade900
                      ),
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            OutlinedButton(
              onPressed: _isDownloading ? null : _pickDirectory,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white, 
                side: BorderSide(color: Colors.grey.shade300), 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
              ),
              child: const Text('Thay đổi', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      ),
    );
  }
}