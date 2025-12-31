// lib/features/matching/domain/models/filter_preferences.dart
import 'package:flutter/material.dart';

/// Modelo que define las preferencias de filtrado de matches
/// Enfocado en lifestyle y afinidad
class FilterPreferences {
  // Básicos
  final RangeValues ageRange;
  final double maxDistance; // en km

  // lifestyle & Físico
  final double? minHeight; // en cm
  final String? exerciseFrequency; // 'Ocasional', 'Regular', 'Diario'
  
  // Intereses (Tags)
  final List<String> selectedInterests;
  final List<String> bodyTypes; // Nueva: Filtro por complexión

  const FilterPreferences({
    this.ageRange = const RangeValues(18, 35),
    this.maxDistance = 50.0,
    this.minHeight,
    this.exerciseFrequency,
    this.selectedInterests = const [],
    this.bodyTypes = const [],
  });

  FilterPreferences copyWith({
    RangeValues? ageRange,
    double? maxDistance,
    double? minHeight,
    String? exerciseFrequency,
    List<String>? selectedInterests,
    List<String>? bodyTypes,
  }) {
    return FilterPreferences(
      ageRange: ageRange ?? this.ageRange,
      maxDistance: maxDistance ?? this.maxDistance,
      minHeight: minHeight ?? this.minHeight,
      exerciseFrequency: exerciseFrequency ?? this.exerciseFrequency,
      selectedInterests: selectedInterests ?? this.selectedInterests,
      bodyTypes: bodyTypes ?? this.bodyTypes,
    );
  }
}
