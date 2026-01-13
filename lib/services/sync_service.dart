import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import '../models/quiz_attempt.dart';
import 'quiz_api.dart';
import 'package:flutter/foundation.dart';

class SyncService {
  static bool _isSyncing = false;

  /// Procesa la cola de intentos pendientes.
  /// Retorna true si todos los pendientes se sincronizaron con éxito.
  static Future<bool> processQueue() async {
    if (_isSyncing) return false;
    _isSyncing = true;

    try {
      final box = Hive.box<QuizAttempt>('quiz_attempts');
      final pendingAttempts = box.values
          .where((a) => a.status == 'pending' || a.status == 'failed')
          .toList();

      if (pendingAttempts.isEmpty) {
        debugPrint('Sync: No hay tareas pendientes.');
        return true;
      }

      bool allSuccess = true;

      for (var attempt in pendingAttempts) {
        try {
          debugPrint('Sync: Intentando subir cuestionario ${attempt.id}...');
          await QuizApi.saveQuizAnswers(attempt.answers);
          
          attempt.status = 'synced';
          attempt.lastError = null;
          await attempt.save();
          
          debugPrint('Sync: Éxito para ID ${attempt.id}');
        } catch (e) {
          allSuccess = false;
          attempt.status = 'failed';
          attempt.retryCount++;
          attempt.lastError = e.toString();
          await attempt.save();
          
          debugPrint('Sync: Error para ID ${attempt.id}: $e');
        }
      }

      // Cleanup: Eliminar registros sincronizados de hace más de 7 días
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final oldRecords = box.values.where((a) => a.status == 'synced' && a.timestamp.isBefore(weekAgo)).toList();
      for (var record in oldRecords) {
        await record.delete();
      }

      return allSuccess;
    } finally {
      _isSyncing = false;
    }
  }

  /// Disparador manual de sincronización (ej: tras login o recuperación de red)
  /// Tiene un pequeño delay para evitar colisiones si se llama varias veces rápido.
  static void triggerSync() {
    Future.delayed(const Duration(seconds: 1), () => processQueue());
  }
}
