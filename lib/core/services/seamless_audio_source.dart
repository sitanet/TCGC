import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;

/// A custom audio source that plays pre-buffered bytes instantly (~1 minute),
/// then seamlessly continues streaming the rest from the server in background.
/// This provides instant playback while the streaming prepares ahead seamlessly.
// ignore: subtype_of_sealed_class
class SeamlessAudioSource extends StreamAudioSource {
  final List<int> _preBufferedBytes;
  final String _streamUrl;
  final int _preBufferSize;
  
  int? _totalLength;
  bool _fetchingRemaining = false;
  final List<int> _streamBuffer = [];
  bool _streamComplete = false;
  final Completer<void> _headersFetched = Completer<void>();
  
  // Progress tracking for UI
  double _downloadProgress = 0.0;
  double get downloadProgress => _downloadProgress;
  
  // Callback for progress updates
  void Function(double progress)? onProgressUpdate;

  SeamlessAudioSource({
    required List<int> preBufferedBytes,
    required String streamUrl,
    this.onProgressUpdate,
  })  : _preBufferedBytes = preBufferedBytes,
        _streamUrl = streamUrl,
        _preBufferSize = preBufferedBytes.length {
    // Start background streaming immediately
    _startBackgroundStream();
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    
    // For initial request (start=0), respond immediately with pre-buffered data
    // Don't wait for headers - play instantly!
    if (start == 0 && !_headersFetched.isCompleted) {
      // Return pre-buffered data immediately for instant playback
      final initialEnd = end ?? _preBufferSize;
      final effectiveEnd = initialEnd.clamp(0, _preBufferSize);
      final responseBytes = _preBufferedBytes.sublist(start, effectiveEnd);
      
      return StreamAudioResponse(
        sourceLength: null, // Unknown until headers fetched
        contentLength: responseBytes.length,
        offset: start,
        stream: Stream.value(Uint8List.fromList(responseBytes)),
        contentType: 'audio/mpeg',
      );
    }
    
    // For subsequent requests, wait for headers if needed
    if (!_headersFetched.isCompleted) {
      await _headersFetched.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );
    }

    final sourceLength = _totalLength ?? (_preBufferSize + _streamBuffer.length);
    
    // Determine effective end
    int effectiveEnd;
    if (end != null) {
      effectiveEnd = end.clamp(start, sourceLength);
    } else {
      effectiveEnd = sourceLength;
    }

    // Build response data from available buffers
    final responseBytes = await _getBytes(start, effectiveEnd);
    
    return StreamAudioResponse(
      sourceLength: _streamComplete ? sourceLength : null,
      contentLength: responseBytes.length,
      offset: start,
      stream: Stream.value(Uint8List.fromList(responseBytes)),
      contentType: 'audio/mpeg',
    );
  }

  Future<List<int>> _getBytes(int start, int end) async {
    final result = <int>[];
    
    for (int i = start; i < end; i++) {
      // Check if byte is in pre-buffer
      if (i < _preBufferSize) {
        result.add(_preBufferedBytes[i]);
      } else {
        // Byte is in stream buffer
        final streamIndex = i - _preBufferSize;
        
        // Wait if we need bytes that haven't been downloaded yet
        // Use shorter wait time for seamless transition
        int waitCount = 0;
        while (streamIndex >= _streamBuffer.length && !_streamComplete) {
          await Future.delayed(const Duration(milliseconds: 10));
          waitCount++;
          // Timeout after 30 seconds to prevent infinite wait
          if (waitCount > 3000) break;
        }
        
        if (streamIndex < _streamBuffer.length) {
          result.add(_streamBuffer[streamIndex]);
        } else {
          // Stream ended before we got all requested bytes
          break;
        }
      }
    }
    
    return result;
  }

  void _startBackgroundStream() async {
    if (_fetchingRemaining) return;
    _fetchingRemaining = true;

    try {
      // First, get the total content length with HEAD request
      try {
        final headResponse = await http.head(Uri.parse(_streamUrl)).timeout(
          const Duration(seconds: 5),
        );
        _totalLength = int.tryParse(headResponse.headers['content-length'] ?? '');
      } catch (e) {
        // Will determine length from stream
      }
      
      if (!_headersFetched.isCompleted) {
        _headersFetched.complete();
      }

      // If pre-buffer contains all content, we're done
      if (_totalLength != null && _totalLength! <= _preBufferSize) {
        _streamComplete = true;
        _downloadProgress = 1.0;
        onProgressUpdate?.call(1.0);
        return;
      }

      // Stream remaining bytes starting from where pre-buffer ends
      final request = http.Request('GET', Uri.parse(_streamUrl));
      request.headers['Range'] = 'bytes=$_preBufferSize-';

      final response = await request.send().timeout(
        const Duration(seconds: 30),
      );
      
      if (response.statusCode == 206 || response.statusCode == 200) {
        // Update total length if we got it from response
        if (_totalLength == null) {
          final contentRange = response.headers['content-range'];
          if (contentRange != null) {
            final match = RegExp(r'/(\d+)').firstMatch(contentRange);
            if (match != null) {
              _totalLength = int.tryParse(match.group(1) ?? '');
            }
          }
        }
        
        final expectedRemaining = _totalLength != null 
            ? _totalLength! - _preBufferSize 
            : response.contentLength ?? 0;
        
        // Stream bytes progressively
        await for (final chunk in response.stream) {
          _streamBuffer.addAll(chunk);
          
          // Update progress
          if (expectedRemaining > 0) {
            _downloadProgress = (_preBufferSize + _streamBuffer.length) / 
                (_preBufferSize + expectedRemaining);
            onProgressUpdate?.call(_downloadProgress);
          }
        }
        
        _streamComplete = true;
        _downloadProgress = 1.0;
        onProgressUpdate?.call(1.0);
      } else {
        _streamComplete = true;
      }
    } catch (e) {
      _streamComplete = true;
      if (!_headersFetched.isCompleted) {
        _headersFetched.complete();
      }
    }
  }
  
  /// Check if enough data is buffered for a given position
  bool hasDataForPosition(Duration position, Duration? totalDuration) {
    if (totalDuration == null || totalDuration.inMilliseconds == 0) return true;
    if (_streamComplete) return true;
    
    final totalBytes = _preBufferSize + _streamBuffer.length;
    final positionRatio = position.inMilliseconds / totalDuration.inMilliseconds;
    final requiredBytes = ((_totalLength ?? totalBytes) * positionRatio).toInt();
    
    return totalBytes >= requiredBytes;
  }
}
