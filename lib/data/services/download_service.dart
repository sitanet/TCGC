import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../domain/entities/sermon.dart';

class DownloadedSermon {
  final Sermon sermon;
  final String localPath;
  final DateTime downloadedAt;
  final int fileSize;

  DownloadedSermon({
    required this.sermon,
    required this.localPath,
    required this.downloadedAt,
    required this.fileSize,
  });

  Map<String, dynamic> toJson() {
    return {
      'sermon': sermon.toJson(),
      'local_path': localPath,
      'downloaded_at': downloadedAt.toIso8601String(),
      'file_size': fileSize,
    };
  }

  factory DownloadedSermon.fromJson(Map<String, dynamic> json) {
    return DownloadedSermon(
      sermon: Sermon.fromJson(json['sermon']),
      localPath: json['local_path'],
      downloadedAt: DateTime.parse(json['downloaded_at']),
      fileSize: json['file_size'] ?? 0,
    );
  }
}

class DownloadService extends ChangeNotifier {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  static const String _downloadsKey = 'downloaded_sermons';
  Directory? _downloadDir;
  List<DownloadedSermon> _downloads = [];
  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _downloading = {};
  bool _isLoaded = false;

  List<DownloadedSermon> get downloads => List.unmodifiable(_downloads);
  int get count => _downloads.length;

  Future<void> initialize() async {
    if (_isLoaded) return;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _downloadDir = Directory('${appDir.path}/downloads');
      if (!await _downloadDir!.exists()) {
        await _downloadDir!.create(recursive: true);
      }
      await _loadDownloads();
      _isLoaded = true;
      debugPrint('DownloadService initialized: ${_downloadDir!.path}');
    } catch (e) {
      debugPrint('DownloadService init error: $e');
    }
  }

  Future<void> _loadDownloads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_downloadsKey);
      if (data != null) {
        final List<dynamic> json = jsonDecode(data);
        _downloads = json.map((j) => DownloadedSermon.fromJson(j)).toList();
        
        // Verify files still exist
        final validDownloads = <DownloadedSermon>[];
        for (final download in _downloads) {
          if (await File(download.localPath).exists()) {
            validDownloads.add(download);
          }
        }
        _downloads = validDownloads;
        await _saveDownloads();
        
        debugPrint('Loaded ${_downloads.length} downloads');
      }
    } catch (e) {
      debugPrint('Error loading downloads: $e');
    }
  }

  Future<void> _saveDownloads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = _downloads.map((d) => d.toJson()).toList();
      await prefs.setString(_downloadsKey, jsonEncode(json));
    } catch (e) {
      debugPrint('Error saving downloads: $e');
    }
  }

  bool isDownloaded(String sermonId) {
    return _downloads.any((d) => d.sermon.id == sermonId);
  }

  bool isDownloading(String sermonId) {
    return _downloading[sermonId] == true;
  }

  double getProgress(String sermonId) {
    return _downloadProgress[sermonId] ?? 0.0;
  }

  String? getLocalPath(String sermonId) {
    try {
      return _downloads.firstWhere((d) => d.sermon.id == sermonId).localPath;
    } catch (e) {
      return null;
    }
  }

  DownloadedSermon? getDownload(String sermonId) {
    try {
      return _downloads.firstWhere((d) => d.sermon.id == sermonId);
    } catch (e) {
      return null;
    }
  }

  Future<bool> downloadSermon(Sermon sermon) async {
    if (_downloadDir == null) await initialize();
    if (isDownloaded(sermon.id) || isDownloading(sermon.id)) return false;
    if (sermon.audioUrl == null || sermon.audioUrl!.isEmpty) return false;

    _downloading[sermon.id] = true;
    _downloadProgress[sermon.id] = 0.0;
    notifyListeners();

    try {
      final request = http.Request('GET', Uri.parse(sermon.audioUrl!));
      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception('Failed to download: ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final fileName = _sanitizeFileName(sermon.id);
      final ext = _getFileExtension(sermon.audioUrl!);
      final filePath = '${_downloadDir!.path}/$fileName$ext';
      final file = File(filePath);
      final sink = file.openWrite();

      int received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          _downloadProgress[sermon.id] = received / contentLength;
          notifyListeners();
        }
      }

      await sink.close();

      final downloadedSermon = DownloadedSermon(
        sermon: sermon,
        localPath: filePath,
        downloadedAt: DateTime.now(),
        fileSize: await file.length(),
      );

      _downloads.insert(0, downloadedSermon);
      await _saveDownloads();

      _downloading[sermon.id] = false;
      _downloadProgress[sermon.id] = 1.0;
      notifyListeners();

      debugPrint('Downloaded: ${sermon.title}');
      return true;
    } catch (e) {
      debugPrint('Download error: $e');
      _downloading[sermon.id] = false;
      _downloadProgress.remove(sermon.id);
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteDownload(String sermonId) async {
    try {
      final download = getDownload(sermonId);
      if (download != null) {
        final file = File(download.localPath);
        if (await file.exists()) {
          await file.delete();
        }
        _downloads.removeWhere((d) => d.sermon.id == sermonId);
        await _saveDownloads();
        notifyListeners();
        debugPrint('Deleted download: $sermonId');
      }
    } catch (e) {
      debugPrint('Error deleting download: $e');
    }
  }

  Future<int> getTotalSize() async {
    int totalSize = 0;
    for (final download in _downloads) {
      totalSize += download.fileSize;
    }
    return totalSize;
  }

  Future<void> clearAllDownloads() async {
    try {
      for (final download in _downloads) {
        final file = File(download.localPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      _downloads.clear();
      await _saveDownloads();
      notifyListeners();
      debugPrint('Cleared all downloads');
    } catch (e) {
      debugPrint('Error clearing downloads: $e');
    }
  }

  String _sanitizeFileName(String id) {
    return id.replaceAll(RegExp(r'[^\w\-]'), '_');
  }

  String _getFileExtension(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.path.isNotEmpty) {
      final path = uri.path.toLowerCase();
      if (path.endsWith('.ogg')) return '.ogg';
      if (path.endsWith('.mp3')) return '.mp3';
      if (path.endsWith('.wav')) return '.wav';
      if (path.endsWith('.m4a')) return '.m4a';
      if (path.endsWith('.aac')) return '.aac';
    }
    return '.mp3';
  }
}
