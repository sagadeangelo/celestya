// lib/screens/compat_quiz_screen.dart
import 'package:flutter/material.dart';

import '../data/compat_questions.dart';
import 'package:Celestya/services/compat_storage.dart'; // Mantener por compatibilidad legacy
import 'package:Celestya/services/quiz_api.dart';
import 'package:Celestya/services/speech_service.dart';
import 'package:Celestya/services/quiz_local_storage.dart';
import 'package:Celestya/models/quiz_attempt.dart';
import 'package:Celestya/widgets/voice_answer_field.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:workmanager/workmanager.dart';

class CompatQuizScreen extends StatefulWidget {
  const CompatQuizScreen({super.key});

  @override
  State<CompatQuizScreen> createState() => _CompatQuizScreenState();
}

class _CompatQuizScreenState extends State<CompatQuizScreen> {
  int _currentIndex = 0;
  bool _isListening = false;
  String _lastWords = '';

  /// Mapa: idPregunta -> conjunto de ids de opciones seleccionadas.
  final Map<String, Set<String>> _answers = {};

  @override
  void initState() {
    super.initState();
    SpeechService.init();
    _resumeProgress();
  }

  Future<void> _resumeProgress() async {
    final saved = await QuizLocalStorage.loadAnswers();
    if (saved.isNotEmpty) {
      setState(() {
        _answers.addAll(saved.map((k, v) => MapEntry(k, v.toSet())));
        // Opcional: Saltar a la última pregunta respondida
        _currentIndex = (_answers.length < compatQuestions.length) 
            ? _answers.length 
            : compatQuestions.length - 1;
      });
    }
  }

  CompatQuestion get _currentQuestion => compatQuestions[_currentIndex];

  bool _isSelected(String qId, String optId) {
    final set = _answers[qId];
    if (set == null) return false;
    return set.contains(optId);
  }

  void _toggleOption(CompatQuestion q, CompatOption opt) {
    setState(() {
      final current = _answers[q.id] ?? <String>{};

      if (q.multi) {
        // Multi-select: agregamos o quitamos del set.
        if (current.contains(opt.id)) {
          current.remove(opt.id);
        } else {
          current.add(opt.id);
        }
        _answers[q.id] = current;
      } else {
        _answers[q.id] = {opt.id};
      }
      
      // Guardado INMEDIATO tras cada cambio
      QuizLocalStorage.saveAnswer(q.id, _answers[q.id]!.toList());
    });
  }

  bool _hasAnswerForCurrent() {
    final set = _answers[_currentQuestion.id];
    return set != null && set.isNotEmpty;
  }

  void _goNext() {
    if (_currentIndex < compatQuestions.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      _finishQuiz();
    }
    setState(() {
      _lastWords = '';
    });
  }

  void _goBack() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
    }
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await SpeechService.init();
      if (available) {
        setState(() => _isListening = true);
        SpeechService.startListening(
          onResult: (val) {
            setState(() {
              _lastWords = val;
              _tryAutoMatch(val);
            });
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      SpeechService.stopListening();
    }
  }

  void _tryAutoMatch(String text) {
    if (text.isEmpty) return;
    final normalized = text.toLowerCase().trim();
    for (var opt in _currentQuestion.options) {
      if (normalized.contains(opt.label.toLowerCase()) || 
          opt.label.toLowerCase().contains(normalized)) {
        _toggleOption(_currentQuestion, opt);
        break; 
      }
    }
  }

  Future<void> _finishQuiz() async {
    // 1. Mostrar Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    // Convertimos Set<String> -> List<String> para persistencia
    final Map<String, dynamic> toSaveAnswers = _answers.map(
      (key, value) => MapEntry(key, value.toList()),
    );

    // 2. Persistencia Local Robusta con Hive (Cola de Sincronización)
    final box = Hive.box<QuizAttempt>('quiz_attempts');
    final attempt = QuizAttempt(
      id: const Uuid().v4(),
      answers: toSaveAnswers,
      timestamp: DateTime.now(),
      status: 'pending',
    );
    await box.add(attempt);

    // Guardar también en el almacenamiento legacy para no romper lógica actual de UI de perfil
    await CompatStorage.saveAnswers(toSaveAnswers);

    try {
      // 3. Intento de subida inmediata a Backend
      await QuizApi.saveQuizAnswers(toSaveAnswers);
      
      attempt.status = 'synced';
      await attempt.save();

      // 4. Limpiar almacenamiento local inmediato al finalizar con éxito
      await QuizLocalStorage.clearAnswers();

      if (!mounted) return;
      Navigator.of(context).pop(); // Cerrar dialog loading
      Navigator.of(context).pop(); // Cerrar pantalla quiz

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Cuestionario sincronizado con el universo! ✨🚀'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Cerrar dialog loading
      
      // Si falla, ya está guardado en Hive, el SyncService (Workmanager) lo intentará después
      Workmanager().registerOneOffTask(
        "sync-quiz-task",
        "sync-quiz-task",
        initialDelay: const Duration(minutes: 5),
      );

      Navigator.of(context).pop(); // Cerramos pantalla
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Guardado localmente. Se sincronizará automáticamente pronto. (Error: $e)'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _currentQuestion;
    final total = compatQuestions.length;
    final current = _currentIndex + 1;
    final progress = current / total;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuestionario de compatibilidad'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6.0),
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            tween: Tween<double>(begin: 0, end: progress),
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.05, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<String>(q.id),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                    children: [
                      Text(
                        'Pregunta $current de $total',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        q.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      VoiceAnswerField(
                        label: 'Tu respuesta por voz',
                        initialValue: _lastWords,
                        onChanged: (val) {
                          setState(() {
                            _lastWords = val;
                            _tryAutoMatch(val);
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      if (q.multi)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.checklist,
                                size: 16,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Selecciona varias opciones',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: q.options.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, idx) {
                          final opt = q.options[idx];
                          final selected = _isSelected(q.id, opt.id);
                          return _OptionCard(
                            label: opt.label,
                            selected: selected,
                            onTap: () => _toggleOption(q, opt),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (_currentIndex > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _goBack,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Anterior'),
                      ),
                    ),
                  if (_currentIndex > 0) const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _hasAnswerForCurrent() ? _goNext : null,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        _currentIndex == total - 1 ? 'Finalizar Cuestionario' : 'Siguiente',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: selected 
                ? colorScheme.primaryContainer 
                : theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected 
                  ? colorScheme.primary 
                  : theme.dividerColor.withOpacity(0.1),
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              if (!selected)
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            children: [
               Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? colorScheme.onPrimaryContainer : theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: selected ? colorScheme.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected 
                        ? colorScheme.primary 
                        : theme.dividerColor.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: selected
                    ? Icon(
                        Icons.check,
                        size: 16,
                        color: colorScheme.onPrimary,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
