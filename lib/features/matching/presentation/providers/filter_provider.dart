// lib/features/matching/presentation/providers/filter_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/filter_preferences.dart';

class FilterNotifier extends StateNotifier<FilterPreferences> {
  FilterNotifier() : super(const FilterPreferences());

  void updateAgeRange(RangeValues range) {
    state = state.copyWith(ageRange: range);
  }

  void updateMaxDistance(double distance) {
    state = state.copyWith(maxDistance: distance);
  }

  void updateMinHeight(double? height) {
    state = state.copyWith(minHeight: height);
  }

  void updateExerciseFrequency(String? frequency) {
    state = state.copyWith(exerciseFrequency: frequency);
  }

  void toggleInterest(String interest) {
    final currentList = List<String>.from(state.selectedInterests);
    if (currentList.contains(interest)) {
      currentList.remove(interest);
    } else {
      currentList.add(interest);
    }
    state = state.copyWith(selectedInterests: currentList);
  }

  void toggleBodyType(String bodyType) {
    final currentList = List<String>.from(state.bodyTypes);
    if (currentList.contains(bodyType)) {
      currentList.remove(bodyType);
    } else {
      currentList.add(bodyType);
    }
    state = state.copyWith(bodyTypes: currentList);
  }

  void resetFilters() {
    state = const FilterPreferences();
  }
}

final filterProvider = StateNotifierProvider<FilterNotifier, FilterPreferences>((ref) {
  return FilterNotifier();
});
