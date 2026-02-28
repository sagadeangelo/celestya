import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../services/audio_service.dart';
import '../services/users_api.dart';
import '../features/profile/presentation/providers/profile_provider.dart';
import '../data/user_profile.dart';
import '../theme/app_theme.dart';

class VoiceIntroWidget extends StatefulWidget {
  final UserProfile profile;
  final WidgetRef ref;

  const VoiceIntroWidget({
    super.key,
    required this.profile,
    required this.ref,
  });

  @override
  State<VoiceIntroWidget> createState() => _VoiceIntroWidgetState();
}

class _VoiceIntroWidgetState extends State<VoiceIntroWidget> {
  final AudioService _audioService = AudioService();

  bool _isRecording = false;
  bool _isPlaying = false;
  String? _recordedPath;
  String? _error;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  bool _forceReRecord = false;

  @override
  void initState() {
    super.initState();
    _recordedPath = widget.profile.voiceIntroPath;

    _audioService.onDurationChanged
        .listen((d) => setState(() => _duration = d));
    _audioService.onPositionChanged
        .listen((p) => setState(() => _position = p));
    _audioService.onPlayerComplete
        .listen((_) => setState(() => _isPlaying = false));
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _audioService.dispose();
    super.dispose();
  }

  void _startRecording() async {
    final success = await _audioService.startRecording();
    if (success) {
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
        _error = null;
        _recordedPath = null;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _recordSeconds++);
      });
    } else {
      setState(() =>
          _error = 'Error al iniciar grabación. Verifica el permiso de micro.');
    }
  }

  void _stopRecording() async {
    _recordTimer?.cancel();
    final path = await _audioService.stopRecording();
    setState(() {
      _isRecording = false;
      _recordedPath = path;
    });
  }

  void _togglePlayback() async {
    final path = _recordedPath ?? widget.profile.voiceIntroUrl;
    if (path == null) return;

    if (_isPlaying) {
      await _audioService.pauseAudio();
      setState(() => _isPlaying = false);
    } else {
      await _audioService.playAudio(path);
      setState(() => _isPlaying = true);
    }
  }

  void _discardRecording() {
    setState(() {
      _recordedPath = null;
      _isPlaying = false;
      _position = Duration.zero;
      if (widget.profile.voiceIntroUrl != null) {
        _forceReRecord = true;
      }
    });
  }

  bool _isSaving = false;

  void _saveRecording() async {
    if (_recordedPath == null) return;

    setState(() => _isSaving = true);

    try {
      final file = File(_recordedPath!);
      await UsersApi.uploadVoiceIntro(file);

      await widget.ref.read(profileProvider.notifier).loadProfile();
      setState(() => _forceReRecord = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Tu voz ha sido guardada en el perfil! 🎙️✨'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Error al guardar audio: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    final hasAudioInProfile = widget.profile.voiceIntroUrl != null;
    final showReviewState =
        (_recordedPath != null || (hasAudioInProfile && !_forceReRecord)) &&
            !_isRecording;
    final showInitialState =
        (_recordedPath == null && (!hasAudioInProfile || _forceReRecord)) &&
            !_isRecording;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            CelestyaColors.mysticalPurple.withOpacity(0.2),
            CelestyaColors.deepNight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isRecording
              ? Colors.red.withOpacity(0.5)
              : CelestyaColors.mysticalPurple.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_isRecording ? Icons.mic_rounded : Icons.audiotrack_rounded,
                  color: _isRecording ? Colors.red : CelestyaColors.starDust),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  showReviewState ? 'Tu presentación' : 'Preséntate con tu voz',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              if (_isRecording) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, color: Colors.red, size: 8),
                      const SizedBox(width: 6),
                      Text(
                        _formatDuration(Duration(seconds: _recordSeconds)),
                        style: const TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _isRecording
                ? 'Grabando tu saludo... cuéntanos de ti.'
                : showReviewState
                    ? 'Escucha cómo quedó y decide si quieres guardarlo o re-grabarlo.'
                    : 'Graba 10-15 segundos. La voz comunica lo que el texto no puede.',
            style: TextStyle(
              color: _isRecording ? Colors.redAccent : Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          if (showInitialState)
            Center(
              child: GestureDetector(
                onTap: _startRecording,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: CelestyaColors.mysticalPurple,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                CelestyaColors.mysticalPurple.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child:
                          const Icon(Icons.mic, color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 12),
                    const Text('Toca para grabar',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          if (_isRecording)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 40,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(15, (index) {
                        return Container(
                          width: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          height: 15 + (index % 5) * 6.0,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _stopRecording,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child:
                          const Icon(Icons.stop, color: Colors.white, size: 32),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Toca para detener',
                      style: TextStyle(color: Colors.redAccent)),
                ],
              ),
            ),
          if (showReviewState)
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _togglePlayback,
                        icon: Icon(
                          _isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          color: CelestyaColors.starDust,
                          size: 40,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 14),
                                activeTrackColor: CelestyaColors.starDust,
                                inactiveTrackColor: Colors.white12,
                                thumbColor: CelestyaColors.starDust,
                              ),
                              child: Slider(
                                value: _position.inMilliseconds.toDouble(),
                                max: _duration.inMilliseconds.toDouble() > 0
                                    ? _duration.inMilliseconds.toDouble()
                                    : 1.0,
                                onChanged: (val) async {
                                  // Seek logic omitted for brevity as per original code
                                },
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_formatDuration(_position),
                                      style: const TextStyle(
                                          color: Colors.white54, fontSize: 10)),
                                  Text(_formatDuration(_duration),
                                      style: const TextStyle(
                                          color: Colors.white54, fontSize: 10)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _discardRecording,
                        icon: const Icon(Icons.delete_outline, size: 20),
                        label: const Text('Re-grabar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _saveRecording,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check, size: 20),
                        label: Text(_isSaving ? 'Guardando...' : 'Me gusta'),
                        style: FilledButton.styleFrom(
                          backgroundColor: CelestyaColors.mysticalPurple,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!,
                  style: const TextStyle(color: Colors.orange, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
