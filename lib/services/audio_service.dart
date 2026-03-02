import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  String? _currentPath;

  // Recording methods
  Future<bool> startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final fileName =
            'voice_intro_${DateTime.now().millisecondsSinceEpoch}.m4a';
        _currentPath = p.join(dir.path, fileName);

        await _recorder.start(const RecordConfig(), path: _currentPath!);
        return true;
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
    return false;
  }

  Future<String?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      return path;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
    return null;
  }

  // Playback methods
  Future<void> playAudio(String path) async {
    try {
      if (path.startsWith('http')) {
        await _player.setUrl(path);
      } else {
        await _player.setFilePath(path);
      }
      await _player.play();
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  Future<void> pauseAudio() async {
    await _player.pause();
  }

  Future<void> stopAudio() async {
    await _player.stop();
  }

  Stream<Duration> get onPositionChanged => _player.positionStream;
  Stream<Duration?> get onDurationChanged => _player.durationStream;
  Stream<void> get onPlayerComplete => _player.playerStateStream
      .where((state) => state.processingState == ProcessingState.completed);

  void dispose() {
    _recorder.dispose();
    _player.dispose();
  }
}
