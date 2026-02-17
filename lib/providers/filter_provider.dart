import 'package:flutter_riverpod/flutter_riverpod.dart';

class DiscoverFilters {
  final int minAge;
  final int maxAge;
  final int maxDistanceKm;

  const DiscoverFilters({
    this.minAge = 18,
    this.maxAge = 45,
    this.maxDistanceKm = 500,
  });

  DiscoverFilters copyWith({
    int? minAge,
    int? maxAge,
    int? maxDistanceKm,
  }) {
    return DiscoverFilters(
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
    );
  }

  @override
  String toString() =>
      'DiscoverFilters(minAge: $minAge, maxAge: $maxAge, maxDistanceKm: $maxDistanceKm)';
}

class FilterNotifier extends StateNotifier<DiscoverFilters> {
  // Configuración inicial por defecto
  static const _defaultMinAge = 18;
  static const _defaultMaxAge = 45;
  static const _defaultMaxDistance = 500;

  FilterNotifier() : super(const DiscoverFilters());

  /// Actualiza los filtros validando que minAge <= maxAge.
  void updateFilters({int? minAge, int? maxAge, int? maxDistanceKm}) {
    int newMin = minAge ?? state.minAge;
    int newMax = maxAge ?? state.maxAge;

    // Validación simple
    if (newMin > newMax) {
      if (minAge != null) {
        // Si se cambió el mínimo y supera al máximo, empujamos el máximo
        newMax = newMin;
      } else {
        // Si se cambió el máximo y es menor al mínimo, bajamos el mínimo
        newMin = newMax;
      }
    }

    state = state.copyWith(
      minAge: newMin,
      maxAge: newMax,
      maxDistanceKm: maxDistanceKm,
    );
  }

  /// Restablece a los valores por defecto
  void reset() {
    state = const DiscoverFilters(
      minAge: _defaultMinAge,
      maxAge: _defaultMaxAge,
      maxDistanceKm: _defaultMaxDistance,
    );
  }
}

final filterProvider =
    StateNotifierProvider<FilterNotifier, DiscoverFilters>((ref) {
  return FilterNotifier();
});
