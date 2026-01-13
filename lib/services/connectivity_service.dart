import 'package:connectivity_plus/connectivity_plus.dart';
import 'sync_service.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();

  /// Inicializa el escucha de conectividad.
  static void init() {
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      // Si alguno de los resultados es móvil o wifi, intentamos sincronizar
      final hasConnection = results.any((r) => 
        r == ConnectivityResult.mobile || 
        r == ConnectivityResult.wifi || 
        r == ConnectivityResult.ethernet
      );

      if (hasConnection) {
        debugPrint('Connectivity: Red recuperada. Disparando sincronización...');
        SyncService.triggerSync();
      }
    });
  }
}
