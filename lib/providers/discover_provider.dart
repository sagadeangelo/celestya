import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/match_candidate.dart';
import '../services/matches_api.dart';
import '../features/matching/presentation/providers/filter_provider.dart';

class DiscoverState {
  final List<MatchCandidate> candidates;
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? backendDebugInfo;

  DiscoverState({
    this.candidates = const [],
    this.isLoading = false,
    this.error,
    this.backendDebugInfo,
  });

  DiscoverState copyWith({
    List<MatchCandidate>? candidates,
    bool? isLoading,
    String? error,
    Map<String, dynamic>? backendDebugInfo,
  }) {
    return DiscoverState(
      candidates: candidates ?? this.candidates,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      backendDebugInfo: backendDebugInfo ?? this.backendDebugInfo,
    );
  }
}

class DiscoverNotifier extends StateNotifier<DiscoverState> {
  final Ref ref;

  DiscoverNotifier(this.ref) : super(DiscoverState());

  Future<void> loadCandidates({bool forceRefresh = false}) async {
    if (forceRefresh) {
      // clear current candidates to force UI refresh
      state = state.copyWith(candidates: [], isLoading: true, error: null);
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      // Read filters from provider
      final filters = ref.read(filterProvider);
      debugPrint(
          '[DiscoverNotifier] Loading candidates with filters: $filters');

      int? dist = filters.maxDistance.round();
      if (dist >= 20000) dist = null;

      final candidates = await MatchesApi.getSuggested(
        maxDistanceKm: dist,
        minAge: filters.ageRange.start.round(),
        maxAge: filters.ageRange.end.round(),
      );
      debugPrint(
          '[DiscoverNotifier] loadCandidates result_count=${candidates.length}');

      // Update state with candidates AND captured debug info
      state = state.copyWith(
        candidates: candidates,
        isLoading: false,
        backendDebugInfo: MatchesApi.lastDebugInfo,
      );
    } catch (e) {
      debugPrint('[DiscoverNotifier] loadCandidates error: $e');
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<bool> likeCandidate(String userId) async {
    try {
      final result = await MatchesApi.likeUser(userId);
      _removeCandidate(userId);
      return result['matched'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<void> passCandidate(String userId) async {
    await MatchesApi.passUser(userId);
    _removeCandidate(userId);
  }

  void _removeCandidate(String userId) {
    final updated = state.candidates.where((c) => c.id != userId).toList();
    state = state.copyWith(candidates: updated);

    // Reload if buffer is empty
    if (updated.isEmpty) {
      loadCandidates();
    }
  }
}

final discoverProvider =
    StateNotifierProvider<DiscoverNotifier, DiscoverState>((ref) {
  return DiscoverNotifier(ref);
});
