// lib/screens/compat_summary_screen.dart
import 'package:flutter/material.dart';

import '../data/compat_questions.dart';
import '../services/compat_storage.dart';

class CompatSummaryScreen extends StatefulWidget {
  const CompatSummaryScreen({super.key});

  @override
  State<CompatSummaryScreen> createState() => _CompatSummaryScreenState();
}

class _CompatSummaryScreenState extends State<CompatSummaryScreen> {
  bool _loading = true;

  /// Mapa final ya tipado: idPregunta -> conjunto de ids seleccionados.
  Map<String, Set<String>> _answers = {};

  @override
  void initState() {
    super.initState();
    _loadAnswers();
  }

  Future<void> _loadAnswers() async {
    // Esto probablemente regresa Map<String, dynamic>? desde SharedPreferences
    final raw = await CompatStorage.loadAnswers(); // puede ser null

    if (!mounted) return;

    final Map<String, Set<String>> parsed = {};

    if (raw != null) {
      raw.forEach((key, value) {
        if (value is Iterable) {
          // Convertimos la lista dinámica a Set<String>
          parsed[key] = value.map((e) => e.toString()).toSet();
        }
      });
    }

    setState(() {
      _answers = parsed;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu compatibilidad'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _answers.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Aún no tenemos respuestas guardadas.\n'
                      'Responde o actualiza tu cuestionario de compatibilidad.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: compatQuestions.length,
                  itemBuilder: (context, index) {
                    final q = compatQuestions[index];
                    final selectedIds = _answers[q.id] ?? <String>{};

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              q.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (selectedIds.isEmpty)
                              Text(
                                'Sin respuesta',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.outline,
                                ),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: q.options
                                    .where((opt) => selectedIds.contains(opt.id))
                                    .map(
                                      (opt) => Chip(
                                        label: Text(opt.label),
                                        backgroundColor:
                                            theme.colorScheme.primaryContainer,
                                        labelStyle: TextStyle(
                                          color: theme
                                              .colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
