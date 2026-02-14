import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../theme/app_theme.dart';

class MatchVoicePlayer extends StatefulWidget {
  final String audioPath;

  const MatchVoicePlayer({super.key, required this.audioPath});

  @override
  State<MatchVoicePlayer> createState() => _MatchVoicePlayerState();
}

class _MatchVoicePlayerState extends State<MatchVoicePlayer> {
  final AudioService _audioService = AudioService();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioService.onDurationChanged
        .listen((d) => setState(() => _duration = d));
    _audioService.onPositionChanged
        .listen((p) => setState(() => _position = p));
    _audioService.onPlayerComplete
        .listen((_) => setState(() => _isPlaying = false));
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  void _togglePlayback() async {
    if (_isPlaying) {
      await _audioService.pauseAudio();
      setState(() => _isPlaying = false);
    } else {
      await _audioService.playAudio(widget.audioPath);
      setState(() => _isPlaying = true);
    }
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: CelestyaColors.mysticalPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: CelestyaColors.mysticalPurple.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlayback,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: CelestyaColors.mysticalPurple,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Escucha su voz',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: CelestyaColors.starDust,
                    inactiveTrackColor: Colors.white10,
                    thumbColor: CelestyaColors.starDust,
                  ),
                  child: Slider(
                    value: _position.inMilliseconds.toDouble(),
                    max: _duration.inMilliseconds.toDouble() > 0
                        ? _duration.inMilliseconds.toDouble()
                        : 1.0,
                    onChanged: (val) {
                      // Seek logic if needed
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          const SizedBox(width: 8),
          // Animated small waveform
          if (_isPlaying)
            SizedBox(
              height: 20,
              child: Row(
                children: List.generate(4, (index) {
                  return Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    height: 8 + (index % 3) * 4.0,
                    decoration: BoxDecoration(
                      color: CelestyaColors.starDust,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
