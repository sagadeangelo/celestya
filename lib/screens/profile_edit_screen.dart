// lib/screens/profile_edit_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/user_profile.dart';
import '../services/profile_service.dart';
import '../widgets/photo_picker_widget.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

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
  // Removed _interestsController in favor of list selection
  List<String> _selectedInterests = [];
  
  // Dropdown values
  Gender? _selectedGender;
  TempleRecommendStatus? _selectedTempleRecommend;
  ActivityLevel? _selectedActivityLevel;
  String? _selectedBodyType;
  
  // Photo paths
  String? _profilePhotoPath;
  List<String> _additionalPhotoPaths = [];

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
    _selectedInterests = List.from(widget.profile.interests);
    
    _selectedGender = widget.profile.gender;
    _selectedTempleRecommend = widget.profile.templeRecommend;
    _selectedActivityLevel = widget.profile.activityLevel;
    _selectedBodyType = widget.profile.bodyType;
    
    // Initialize photo paths
    _profilePhotoPath = widget.profile.profilePhotoUrl;
    _additionalPhotoPaths = List.from(widget.profile.photoUrls);
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
    // _interestsController removed
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Los servicios de ubicación están desactivados.')),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permisos de ubicación denegados')),
          );
        }
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permisos de ubicación permanentemente denegados')),
        );
      }
      return;
    } 

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Obteniendo ubicación...')),
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      final placemarks = await placemarkFromCoordinates(
        position.latitude, 
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _locationController.text = '${place.locality}, ${place.administrativeArea}';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error obteniendo ubicación: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);

    setState(() => _saving = true);

    // Interests are already in _selectedInterests list

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
      bodyType: _selectedBodyType,
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
      interests: _selectedInterests, // Updated from text input
      profilePhotoUrl: _profilePhotoPath,
      photoUrls: _additionalPhotoPaths,
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

  Future<void> _pickProfilePhoto() async {
    final photoPath = await ImagePickerHelper.pickImage(context);
    if (photoPath != null) {
      setState(() {
        _profilePhotoPath = photoPath;
      });
    }
  }

  Future<void> _pickAdditionalPhoto() async {
    if (_additionalPhotoPaths.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Máximo 6 fotos adicionales'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final photoPath = await ImagePickerHelper.pickImage(context);
    if (photoPath != null) {
      setState(() {
        _additionalPhotoPaths.add(photoPath);
      });
    }
  }

  void _removeProfilePhoto() {
    setState(() {
      _profilePhotoPath = null;
    });
  }

  void _removeAdditionalPhoto(int index) {
    setState(() {
      _additionalPhotoPaths.removeAt(index);
    });
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
            // Photos Section
            _buildSectionHeader('Fotos', Icons.photo_library),
            const SizedBox(height: 16),
            
            // Profile Photo
            Center(
              child: Column(
                children: [
                  PhotoPickerWidget(
                    photoPath: _profilePhotoPath,
                    onTap: _pickProfilePhoto,
                    onRemove: _profilePhotoPath != null ? _removeProfilePhoto : null,
                    isMainPhoto: true,
                    size: 140,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Foto de perfil (requerida)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Additional Photos
            Text(
              'Fotos adicionales (hasta 6)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _additionalPhotoPaths.length < 6 
                  ? _additionalPhotoPaths.length + 1 
                  : 6,
              itemBuilder: (context, index) {
                if (index < _additionalPhotoPaths.length) {
                  // Show existing photo
                  return PhotoPickerWidget(
                    photoPath: _additionalPhotoPaths[index],
                    onTap: () {}, // No action on tap for existing photos
                    onRemove: () => _removeAdditionalPhoto(index),
                    size: 100,
                  );
                } else {
                  // Show add button
                  return PhotoPickerWidget(
                    photoPath: null,
                    onTap: _pickAdditionalPhoto,
                    size: 100,
                  );
                }
              },
            ),
            
            const SizedBox(height: 32),
            
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
                    initialValue: _selectedGender,
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

            // Complexión (Nuevo)
            DropdownButtonFormField<String>(
              initialValue: _selectedBodyType,
              decoration: const InputDecoration(
                labelText: 'Complexión Física',
                helperText: 'Como te describes a ti mismo',
                prefixIcon: Icon(Icons.accessibility_new),
                border: OutlineInputBorder(),
              ),
              items: kBodyTypeOptions.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedBodyType = value),
            ),
            const SizedBox(height: 16),
                        
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Ubicación',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.location_on),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.my_location, color: Colors.blue),
                  onPressed: _getCurrentLocation,
                  tooltip: 'Usar mi ubicación GPS',
                ),
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
              initialValue: _selectedTempleRecommend,
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
              initialValue: _selectedActivityLevel,
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
            
            Text(
              'Intereses (Selecciona al menos 3)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: kInterestOptions.map((interest) {
                final isSelected = _selectedInterests.contains(interest);
                return FilterChip(
                  label: Text(interest),
                  selected: isSelected,
                  onSelected: (bool selected) {
                    setState(() {
                      if (selected) {
                        _selectedInterests.add(interest);
                      } else {
                        _selectedInterests.remove(interest);
                      }
                    });
                  },
                );
              }).toList(),
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
