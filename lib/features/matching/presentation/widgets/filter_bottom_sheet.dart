// lib/features/matching/presentation/widgets/filter_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/user_profile.dart';
import '../providers/filter_provider.dart';

class FilterBottomSheet extends ConsumerWidget {
  const FilterBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(filterProvider);
    final notifier = ref.read(filterProvider.notifier);
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filtros',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: notifier.resetFilters,
                  child: const Text('Limpiar'),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                // RANGO DE EDAD
                _SectionTitle(title: 'Rango de Edad', value: '${filters.ageRange.start.round()} - ${filters.ageRange.end.round()}'),
                RangeSlider(
                  values: filters.ageRange,
                  min: 18,
                  max: 60,
                  divisions: 42,
                  labels: RangeLabels(
                    filters.ageRange.start.round().toString(),
                    filters.ageRange.end.round().toString(),
                  ),
                  onChanged: notifier.updateAgeRange,
                ),

                const SizedBox(height: 20),

                // DISTANCIA MÁXIMA
                _SectionTitle(title: 'Distancia Máxima', value: '${filters.maxDistance.round()} km'),
                Slider(
                  value: filters.maxDistance,
                  min: 10,
                  max: 200,
                  divisions: 19,
                  label: '${filters.maxDistance.round()} km',
                  onChanged: notifier.updateMaxDistance,
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
                      final isSelected = filters.minHeight == height.toDouble();
                      return ChoiceChip(
                        label: Text('$height+'),
                        selected: isSelected,
                        onSelected: (selected) {
                          notifier.updateMinHeight(selected ? height.toDouble() : null);
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // COMPLEXIÓN (Nuevo)
                const _SectionTitle(title: 'Complexión'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: kBodyTypeOptions.map((type) {
                    final isSelected = filters.bodyTypes.contains(type);
                    return FilterChip(
                      label: Text(type),
                      selected: isSelected,
                        checkmarkColor: Colors.white,
                        selectedColor: theme.colorScheme.secondary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      onSelected: (_) => notifier.toggleBodyType(type),
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
                    final isSelected = filters.exerciseFrequency == freq;
                    return FilterChip(
                      label: Text(freq),
                      selected: isSelected,
                      onSelected: (selected) {
                        notifier.updateExerciseFrequency(selected ? freq : null);
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
                    '🎵 Música', '✈️ Viajes', '🎬 Cine', '🐶 Mascotas',
                    '🍳 Cocina', '🏔️ Aire Libre', '🎨 Arte', '📚 Lectura',
                    '💃 Baile', '🎮 Gaming'
                  ].map((interest) {
                    final isSelected = filters.selectedInterests.contains(interest);
                    return FilterChip(
                      label: Text(interest),
                      selected: isSelected,
                      checkmarkColor: Colors.white,
                      selectedColor: theme.colorScheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      onSelected: (_) => notifier.toggleInterest(interest),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 100), // Espacio para el botón flotante
              ],
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
