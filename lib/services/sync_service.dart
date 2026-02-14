import 'package:hive/hive.dart';
import '../models/quiz_attempt.dart';
import 'quiz_api.dart';
import 'package:flutter/foundation.dart';

class SyncService {
  static bool _isSyncing = false;

  /// Procesa la cola de intentos pendientes.
  static Future<bool> processQueue() async {
    if (_isSyncing) return false;
    _isSyncing = true;

    try {
      final box = Hive.box<QuizAttempt>('quiz_attempts');
      final pendingAttempts = box.values
          .where((a) => a.status == 'pending' || a.status == 'failed')
          .toList();

      if (pendingAttempts.isEmpty) {
        if (kDebugMode) {
          debugPrint('Sync: Nada pendiente.');
        }
        return true;
      }

      bool allSuccess = true;
      if (kDebugMode) {
        debugPrint('Sync: Iniciando subida de ${pendingAttempts.length} elementos...');
      }

      for (var attempt in pendingAttempts) {
        try {
          if (kDebugMode) {
            debugPrint('Sync: Subiendo ID ${attempt.id}...');
          }
          await QuizApi.saveQuizAnswers(attempt.answers);
          
          attempt.status = 'synced';
          attempt.lastError = null;
          await attempt.save();
          
          if (kDebugMode) {
            debugPrint('Sync: Éxito ID ${attempt.id}');
          }
        } catch (e) {
          final errStr = e.toString();
          if (kDebugMode) {
            debugPrint('Sync: ERROR en ID ${attempt.id}: $errStr');
          }
          
          allSuccess = false;
          attempt.status = 'failed';
          attempt.retryCount++;
          attempt.lastError = errStr;
          await attempt.save();

          // SI ES ERROR 401: ABORTAR TODO EL BUCLE
          // No sirve de nada seguir intentando con el resto si la sesión está rota.
          if (errStr.contains('401') || errStr.toLowerCase().contains('token')) {
            if (kDebugMode) {
              debugPrint('Sync: ABORTANDO sincronización por error de autenticación (401).');
            }
            return false; 
          }
        }
      }

      return allSuccess;
    } finally {
      _isSyncing = false;
    }
  }

  /// Limpia todos los intentos de la cola (Nuclear)
  static Future<void> clearQueue() async {
    final box = Hive.box<QuizAttempt>('quiz_attempts');
    await box.clear();
    if (kDebugMode) {
      debugPrint('Sync: Cola de intentos borrada.');
    }
  }

  static void triggerSync() {
    Future.delayed(const Duration(seconds: 1), () => processQueue());
  }
}
