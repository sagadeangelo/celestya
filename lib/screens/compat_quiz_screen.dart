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
                      const SizedBox(height: 8),
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
