// lib/screens/compat_quiz_screen.dart
import 'package:flutter/material.dart';

import '../data/compat_questions.dart';
import 'package:Celestya/services/compat_storage.dart';

class CompatQuizScreen extends StatefulWidget {
  const CompatQuizScreen({super.key});

  @override
  State<CompatQuizScreen> createState() => _CompatQuizScreenState();
}

class _CompatQuizScreenState extends State<CompatQuizScreen> {
  int _currentIndex = 0;

  /// Mapa: idPregunta -> conjunto de ids de opciones seleccionadas.
  final Map<String, Set<String>> _answers = {};

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
        // Single-select: reemplazamos el set completo.
        _answers[q.id] = {opt.id};
      }
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
  }

  void _goBack() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
    }
  }

  Future<void> _finishQuiz() async {
    // Convertimos Set<String> -> List<String> para poder guardar como JSON.
    final Map<String, dynamic> toSave = _answers.map(
      (key, value) => MapEntry(key, value.toList()),
    );

    await CompatStorage.saveAnswers(toSave);

    if (!mounted) return;

    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Gracias por responder tu cuestionario de compatibilidad ✨',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _currentQuestion;
    final total = compatQuestions.length;
    final current = _currentIndex + 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuestionario de compatibilidad'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              '“Antes de comenzar, te haremos 12 preguntas. '
              'Responde con total honestidad: así podremos presentarte personas '
              'que podrían llegar a ser más compatibles contigo y con lo que buscas.”',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Pregunta $current de $total',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                q.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: q.options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  final opt = q.options[idx];
                  final selected = _isSelected(q.id, opt.id);

                  return ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: kOptionMinHeight,
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: kOptionPadding,
                        shape: RoundedRectangleBorder(
                          borderRadius: kOptionRadius,
                        ),
                        backgroundColor: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.surface,
                        foregroundColor: selected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: () => _toggleOption(q, opt),
                      child: Text(opt.label),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_currentIndex > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _goBack,
                      child: const Text('Anterior'),
                    ),
                  ),
                if (_currentIndex > 0) const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _hasAnswerForCurrent() ? _goNext : null,
                    child: Text(
                      _currentIndex == total - 1 ? 'Finalizar' : 'Siguiente',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
