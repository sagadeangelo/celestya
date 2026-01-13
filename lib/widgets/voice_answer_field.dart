import 'package:flutter/material.dart';
import '../services/speech_service.dart';

class VoiceAnswerField extends StatefulWidget {
  final String label;
  final String initialValue;
  final Function(String) onChanged;

  const VoiceAnswerField({
    super.key,
    required this.label,
    this.initialValue = '',
    required this.onChanged,
  });

  @override
  State<VoiceAnswerField> createState() => _VoiceAnswerFieldState();
}

class _VoiceAnswerFieldState extends State<VoiceAnswerField> {
  late TextEditingController _controller;
  bool _isListening = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(VoiceAnswerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue && _controller.text != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleListening() async {
    if (!_isListening) {
      setState(() {
        _errorMessage = null;
      });
      final available = await SpeechService.init();
      if (available) {
        setState(() => _isListening = true);
        await SpeechService.startListening(
          onResult: (text) {
            setState(() {
              _controller.text = text;
              widget.onChanged(text);
            });
          },
          onError: (err) {
            setState(() {
              _isListening = false;
              _errorMessage = err;
            });
          },
        );
      } else {
        setState(() {
          _errorMessage = 'Micro no disponible';
        });
      }
    } else {
      SpeechService.stopListening();
      setState(() => _isListening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
          child: Text(
            widget.label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: widget.onChanged,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'Toca el micro y cuéntanos...',
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _toggleListening,
              child: Tooltip(
                message: _isListening ? 'Detener' : 'Hablar',
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _isListening ? Colors.red.withOpacity(0.2) : Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                    boxShadow: _isListening ? [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 15,
                        spreadRadius: 2,
                      )
                    ] : [],
                    border: Border.all(
                      color: _isListening ? Colors.red : Colors.white24,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? Colors.red : Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_isListening)
          const Padding(
            padding: EdgeInsets.only(top: 10.0, left: 4.0),
            child: Row(
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                ),
                SizedBox(width: 8),
                Text(
                  'Te escucho... habla ahora',
                  style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 4.0),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.orange, fontSize: 13),
            ),
          ),
      ],
    );
  }
}
