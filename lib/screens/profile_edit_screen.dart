// lib/screens/profile_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/user_profile.dart';
import '../services/profile_service.dart';

class ProfileEditScreen extends StatefulWidget {
  final UserProfile profile;

  const ProfileEditScreen({
    super.key,
    required this.profile,
  });

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProfileService _profileService = ProfileService();
  
  bool _saving = false;
  
  // Controllers for text fields
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _heightController;
  late TextEditingController _locationController;
  late TextEditingController _stakeWardController;
  late TextEditingController _missionServedController;
  late TextEditingController _missionYearsController;
  late TextEditingController _favoriteCallingController;
  late TextEditingController _favoriteScriptureController;
  late TextEditingController _bioController;
  late TextEditingController _educationController;
  late TextEditingController _occupationController;
  late TextEditingController _interestsController;
  
  // Dropdown values
  Gender? _selectedGender;
  TempleRecommendStatus? _selectedTempleRecommend;
  ActivityLevel? _selectedActivityLevel;

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers with existing profile data
    _nameController = TextEditingController(text: widget.profile.name);
    _ageController = TextEditingController(
      text: widget.profile.age?.toString() ?? '',
    );
    _heightController = TextEditingController(
      text: widget.profile.heightCm?.toString() ?? '',
    );
    _locationController = TextEditingController(text: widget.profile.location);
    _stakeWardController = TextEditingController(text: widget.profile.stakeWard);
    _missionServedController = TextEditingController(text: widget.profile.missionServed);
    _missionYearsController = TextEditingController(text: widget.profile.missionYears);
    _favoriteCallingController = TextEditingController(text: widget.profile.favoriteCalling);
    _favoriteScriptureController = TextEditingController(text: widget.profile.favoriteScripture);
    _bioController = TextEditingController(text: widget.profile.bio);
    _educationController = TextEditingController(text: widget.profile.education);
    _occupationController = TextEditingController(text: widget.profile.occupation);
    _interestsController = TextEditingController(
      text: widget.profile.interests.join(', '),
    );
    
    _selectedGender = widget.profile.gender;
    _selectedTempleRecommend = widget.profile.templeRecommend;
    _selectedActivityLevel = widget.profile.activityLevel;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _locationController.dispose();
    _stakeWardController.dispose();
    _missionServedController.dispose();
    _missionYearsController.dispose();
    _favoriteCallingController.dispose();
    _favoriteScriptureController.dispose();
    _bioController.dispose();
    _educationController.dispose();
    _occupationController.dispose();
    _interestsController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);

    // Parse interests from comma-separated string
    final interestsList = _interestsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final updatedProfile = UserProfile(
      name: _nameController.text.trim(),
      age: int.tryParse(_ageController.text),
      gender: _selectedGender,
      heightCm: int.tryParse(_heightController.text),
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      stakeWard: _stakeWardController.text.trim().isEmpty
          ? null
          : _stakeWardController.text.trim(),
      missionServed: _missionServedController.text.trim().isEmpty
          ? null
          : _missionServedController.text.trim(),
      missionYears: _missionYearsController.text.trim().isEmpty
          ? null
          : _missionYearsController.text.trim(),
      templeRecommend: _selectedTempleRecommend,
      activityLevel: _selectedActivityLevel,
      favoriteCalling: _favoriteCallingController.text.trim().isEmpty
          ? null
          : _favoriteCallingController.text.trim(),
      favoriteScripture: _favoriteScriptureController.text.trim().isEmpty
          ? null
          : _favoriteScriptureController.text.trim(),
      bio: _bioController.text.trim().isEmpty
          ? null
          : _bioController.text.trim(),
      education: _educationController.text.trim().isEmpty
          ? null
          : _educationController.text.trim(),
      occupation: _occupationController.text.trim().isEmpty
          ? null
          : _occupationController.text.trim(),
      interests: interestsList,
      profilePhotoUrl: widget.profile.profilePhotoUrl,
      photoUrls: widget.profile.photoUrls,
    );

    final success = await _profileService.saveProfile(updatedProfile);

    setState(() => _saving = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil guardado exitosamente')),
      );
      Navigator.of(context).pop(true); // Return true to indicate success
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al guardar el perfil'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar perfil'),
        actions: [
          if (_saving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text('Guardar'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Basic Information Section
            _buildSectionHeader('Información básica', Icons.person),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre completo',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El nombre es requerido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ageController,
                    decoration: const InputDecoration(
                      labelText: 'Edad',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.cake),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Requerido';
                      }
                      final age = int.tryParse(value);
                      if (age == null || age < 18 || age > 100) {
                        return 'Edad inválida';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<Gender>(
                    value: _selectedGender,
                    decoration: const InputDecoration(
                      labelText: 'Género',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.wc),
                    ),
                    items: Gender.values.map((gender) {
                      return DropdownMenuItem(
                        value: gender,
                        child: Text(gender.displayName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedGender = value);
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Requerido';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _heightController,
              decoration: const InputDecoration(
                labelText: 'Altura (cm)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.height),
                helperText: 'Ejemplo: 170 cm',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final height = int.tryParse(value);
                  if (height == null || height < 100 || height > 250) {
                    return 'Altura inválida';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Ubicación',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
                helperText: 'Ciudad, Estado',
              ),
            ),
            
            const SizedBox(height: 32),
            
            // LDS Information Section
            _buildSectionHeader('Información LDS', Icons.church),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _stakeWardController,
              decoration: const InputDecoration(
                labelText: 'Estaca/Barrio',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_city),
                helperText: 'Ejemplo: Ciudad de México Stake, Polanco Ward',
              ),
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _missionServedController,
              decoration: const InputDecoration(
                labelText: 'Misión servida (opcional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.flight_takeoff),
                helperText: 'Ejemplo: Mexico City South Mission',
              ),
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _missionYearsController,
              decoration: const InputDecoration(
                labelText: 'Años de misión (opcional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
                helperText: 'Ejemplo: 2018-2020',
              ),
            ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<TempleRecommendStatus>(
              value: _selectedTempleRecommend,
              decoration: const InputDecoration(
                labelText: 'Recomendación del templo',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance),
              ),
              items: TempleRecommendStatus.values.map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(status.displayName),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedTempleRecommend = value);
              },
            ),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<ActivityLevel>(
              value: _selectedActivityLevel,
              decoration: const InputDecoration(
                labelText: 'Nivel de actividad',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.favorite),
              ),
              items: ActivityLevel.values.map((level) {
                return DropdownMenuItem(
                  value: level,
                  child: Text(level.displayName),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedActivityLevel = value);
              },
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _favoriteCallingController,
              decoration: const InputDecoration(
                labelText: 'Algún llamamiento que más hayas amado (opcional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.volunteer_activism),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _favoriteScriptureController,
              decoration: const InputDecoration(
                labelText: 'Escritura favorita (opcional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.menu_book),
                helperText: 'Biblia o Libro de Mormón',
              ),
              maxLines: 2,
            ),
            
            const SizedBox(height: 32),
            
            // About Me Section
            _buildSectionHeader('Sobre mí', Icons.info),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _bioController,
              decoration: const InputDecoration(
                labelText: 'Biografía',
                border: OutlineInputBorder(),
                helperText: 'Cuéntanos sobre ti',
              ),
              maxLines: 5,
              maxLength: 500,
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _interestsController,
              decoration: const InputDecoration(
                labelText: 'Intereses',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.interests),
                helperText: 'Separados por comas: lectura, deportes, música',
              ),
              maxLines: 2,
            ),
            
            const SizedBox(height: 32),
            
            // Education & Career Section
            _buildSectionHeader('Educación y carrera', Icons.school),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _educationController,
              decoration: const InputDecoration(
                labelText: 'Educación',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.school),
                helperText: 'Ejemplo: Licenciatura en Ingeniería',
              ),
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _occupationController,
              decoration: const InputDecoration(
                labelText: 'Ocupación',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.work),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Save Button (also in AppBar)
            FilledButton.icon(
              onPressed: _saving ? null : _saveProfile,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_saving ? 'Guardando...' : 'Guardar perfil'),
            ),
            
            const SizedBox(height: 16),
            
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
