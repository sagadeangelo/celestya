// lib/features/matching/presentation/widgets/filter_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/user_profile.dart';
import '../../domain/models/filter_preferences.dart';
import '../providers/filter_provider.dart';
import '../../../../features/profile/presentation/providers/profile_provider.dart';
import '../../../../providers/discover_provider.dart';

class FilterBottomSheet extends ConsumerStatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  ConsumerState<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<FilterBottomSheet> {
  late FilterPreferences _localFilters;

  @override
  void initState() {
    super.initState();
    // Initialize local state with current provider state
    _localFilters = ref.read(filterProvider);
  }

  void _applyFilters() {
    ref.read(filterProvider.notifier).setFilters(_localFilters);
    // Reload candidates with new filters
    ref.read(discoverProvider.notifier).loadCandidates(forceRefresh: true);
    Navigator.pop(context);
  }

  void _resetFilters() {
    setState(() {
      _localFilters = const FilterPreferences();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userProfileAsync = ref.watch(profileProvider);
    final userProfile = userProfileAsync.valueOrNull;

    // Check if user has location data
    final hasLocation =
        userProfile?.latitude != null && userProfile?.longitude != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90, // Slightly taller
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          // Handle drag
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filtros',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: _resetFilters,
                  child: const Text('Limpiar'),
                ),
              ],
            ),
          ),

          const Divider(),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                // RANGO DE EDAD
                _SectionTitle(
                    title: 'Rango de Edad',
                    value:
                        '${_localFilters.ageRange.start.round()} - ${_localFilters.ageRange.end.round()}${_localFilters.ageRange.end.round() >= 75 ? '+' : ''}'),
                RangeSlider(
                  values: _localFilters.ageRange,
                  min: 18,
                  max: 75,
                  divisions: 57,
                  labels: RangeLabels(
                    _localFilters.ageRange.start.round().toString(),
                    _localFilters.ageRange.end.round() >= 75
                        ? '75+'
                        : _localFilters.ageRange.end.round().toString(),
                  ),
                  onChanged: (values) {
                    setState(() => _localFilters =
                        _localFilters.copyWith(ageRange: values));
                  },
                ),

                const SizedBox(height: 20),

                // DISTANCIA MÁXIMA
                _SectionTitle(
                    title: 'Distancia Máxima',
                    value: hasLocation
                        ? (_localFilters.maxDistance >= 300
                            ? 'Mundial 🌍'
                            : '${_localFilters.maxDistance.round()} km')
                        : 'No disponible'),
                if (!hasLocation)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      'Habilita tu ubicación en el perfil para usar este filtro.',
                      style: TextStyle(
                          color: theme.colorScheme.error, fontSize: 12),
                    ),
                  ),
                Slider(
                  value: _localFilters.maxDistance > 300
                      ? 300
                      : _localFilters.maxDistance,
                  min: 10,
                  max: 300,
                  divisions: 29,
                  activeColor: theme.colorScheme.primary,
                  label: _localFilters.maxDistance >= 300
                      ? 'Mundial'
                      : '${_localFilters.maxDistance.round()} km',
                  onChanged: hasLocation
                      ? (value) {
                          // Map 300 (max slider) to 40000 (Earth circumference ~ global)
                          final distance = value >= 300 ? 40000.0 : value;
                          setState(() => _localFilters =
                              _localFilters.copyWith(maxDistance: distance));
                        }
                      : null, // Disabled if no location
                ),

                const Divider(height: 40),

                // ALTURA
                const _SectionTitle(title: 'Altura Mínima (cm)'),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 6,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, index) {
                      final height = 150 + (index * 5); // 150, 155, 160...
                      final isSelected =
                          _localFilters.minHeight == height.toDouble();
                      return ChoiceChip(
                        label: Text('$height+'),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _localFilters = _localFilters.copyWith(
                                minHeight: selected ? height.toDouble() : null);
                          });
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // ESTADO CIVIL
                const _SectionTitle(title: 'Estado Civil'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: MaritalStatus.values.map((status) {
                    final isSelected =
                        _localFilters.maritalStatus.contains(status.name);
                    return FilterChip(
                      label: Text(status.displayName),
                      selected: isSelected,
                      checkmarkColor: Colors.white,
                      selectedColor: theme.colorScheme.secondary,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : theme.textTheme.bodyMedium?.color,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      onSelected: (_) {
                        final currentList =
                            List<String>.from(_localFilters.maritalStatus);
                        if (currentList.contains(status.name)) {
                          currentList.remove(status.name);
                        } else {
                          currentList.add(status.name);
                        }
                        setState(() => _localFilters =
                            _localFilters.copyWith(maritalStatus: currentList));
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // HIJOS
                const _SectionTitle(title: 'Hijos'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    FilterChip(
                      label: const Text('Con Hijos'),
                      selected: _localFilters.childrenPreference == 'con_hijos',
                      checkmarkColor: Colors.white,
                      selectedColor: theme.colorScheme.secondary,
                      labelStyle: TextStyle(
                        color: _localFilters.childrenPreference == 'con_hijos'
                            ? Colors.white
                            : theme.textTheme.bodyMedium?.color,
                      ),
                      onSelected: (_) {
                        setState(() {
                          _localFilters = _localFilters.copyWith(
                              childrenPreference:
                                  _localFilters.childrenPreference ==
                                          'con_hijos'
                                      ? null
                                      : 'con_hijos');
                        });
                      },
                    ),
                    const SizedBox(width: 12),
                    FilterChip(
                      label: const Text('Sin Hijos'),
                      selected: _localFilters.childrenPreference == 'sin_hijos',
                      checkmarkColor: Colors.white,
                      selectedColor: theme.colorScheme.secondary,
                      labelStyle: TextStyle(
                        color: _localFilters.childrenPreference == 'sin_hijos'
                            ? Colors.white
                            : theme.textTheme.bodyMedium?.color,
                      ),
                      onSelected: (_) {
                        setState(() {
                          _localFilters = _localFilters.copyWith(
                              childrenPreference:
                                  _localFilters.childrenPreference ==
                                          'sin_hijos'
                                      ? null
                                      : 'sin_hijos');
                        });
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // COMPLEXIÓN
                const _SectionTitle(title: 'Complexión'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: kBodyTypeOptions.map((type) {
                    final isSelected = _localFilters.bodyTypes.contains(type);
                    return FilterChip(
                      label: Text(type),
                      selected: isSelected,
                      checkmarkColor: Colors.white,
                      selectedColor: theme.colorScheme.secondary,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : theme.textTheme.bodyMedium?.color,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      onSelected: (_) {
                        final currentList =
                            List<String>.from(_localFilters.bodyTypes);
                        if (currentList.contains(type)) {
                          currentList.remove(type);
                        } else {
                          currentList.add(type);
                        }
                        setState(() => _localFilters =
                            _localFilters.copyWith(bodyTypes: currentList));
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // FRECUENCIA DE EJERCICIO
                const _SectionTitle(title: 'Ejercicio'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: ['Ocasional', 'Regular', 'Diario'].map((freq) {
                    final isSelected = _localFilters.exerciseFrequency == freq;
                    return FilterChip(
                      label: Text(freq),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _localFilters = _localFilters.copyWith(
                              exerciseFrequency: selected ? freq : null);
                        });
                      },
                    );
                  }).toList(),
                ),

                const Divider(height: 40),

                // INTERESES
                const _SectionTitle(title: 'Intereses y Hobbies'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    '🎵 Música',
                    '✈️ Viajes',
                    '🎬 Cine',
                    '🐶 Mascotas',
                    '🍳 Cocina',
                    '🏔️ Aire Libre',
                    '🎨 Arte',
                    '📚 Lectura',
                    '💃 Baile',
                    '🎮 Gaming'
                  ].map((interest) {
                    final isSelected =
                        _localFilters.selectedInterests.contains(interest);
                    return FilterChip(
                      label: Text(interest),
                      selected: isSelected,
                      checkmarkColor: Colors.white,
                      selectedColor: theme.colorScheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : theme.textTheme.bodyMedium?.color,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      onSelected: (_) {
                        final currentList =
                            List<String>.from(_localFilters.selectedInterests);
                        if (currentList.contains(interest)) {
                          currentList.remove(interest);
                        } else {
                          currentList.add(interest);
                        }
                        setState(() => _localFilters = _localFilters.copyWith(
                            selectedInterests: currentList));
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),

          // Apply Button Area
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                  20, 10, 20, 10), // Reducido verticalmente
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(
                    top: BorderSide(color: Colors.grey.withOpacity(0.2))),
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _applyFilters,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor:
                        theme.colorScheme.primary, // Asegurar morado/primario
                  ),
                  child: const Text('Aplicar Filtros',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? value;

  const _SectionTitle({required this.title, this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        if (value != null)
          Text(
            value!,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
      ],
    );
  }
}
