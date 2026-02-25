// lib/screens/profile_edit_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/user_profile.dart';
import '../services/profile_service.dart';
import '../widgets/photo_picker_widget.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/profile/presentation/providers/profile_provider.dart';
import '../services/users_api.dart';
import '../widgets/profile_image.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  final UserProfile profile;

  const ProfileEditScreen({
    super.key,
    required this.profile,
  });

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProfileService _profileService = ProfileService();

  bool _saving = false;

  // Controllers for text fields
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
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
  MaritalStatus? _selectedMaritalStatus;
  bool _hasChildren = false;
  TempleRecommendStatus? _selectedTempleRecommend;
  ActivityLevel? _selectedActivityLevel;
  String? _selectedBodyType;

  // Birthdate and Calculated Age
  DateTime? _selectedBirthdate;
  int? _calculatedAge;

  // Photo paths
  String? _profilePhotoPath;
  String? _profilePhotoKey;
  List<GalleryItem> _galleryItems = [];
  bool _isUploadingGallery = false;

  // Geolocation State
  double? _latitude;
  double? _longitude;
  bool _gettingLocation = false;
  String? _locationError;

  bool _hydrated = false;

  @override
  void initState() {
    super.initState();

    // Initialize all controllers first (empty or placeholder)
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _heightController = TextEditingController();
    _locationController = TextEditingController();
    _stakeWardController = TextEditingController();
    _missionServedController = TextEditingController();
    _missionYearsController = TextEditingController();
    _favoriteCallingController = TextEditingController();
    _favoriteScriptureController = TextEditingController();
    _bioController = TextEditingController();
    _educationController = TextEditingController();
    _occupationController = TextEditingController();

    _hydrate();

    // Auto-detect location if empty
    if (_locationController.text.trim().isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _getCurrentLocation();
      });
    }
  }

  void _hydrate() {
    if (_hydrated) return;

    final p = widget.profile;

    // Sanitización rigurosa para evitar el literal "null" en el controlador
    // Sanitización rigurosa
    final rawName = p.name ?? "";
    final cleanName = rawName
        .replaceAll(RegExp(r'\bnull\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'[,\\.\\s]+$'), '')
        .replaceAll(RegExp(r'^[,\\.\\s]+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Split logic
    final parts = cleanName.split(' ');
    if (parts.isNotEmpty) {
      _firstNameController.text = parts.first;
      if (parts.length > 1) {
        _lastNameController.text = parts.sublist(1).join(' ');
      } else {
        _lastNameController.text = '';
      }
    } else {
      _firstNameController.text = '';
      _lastNameController.text = '';
    }
    _heightController.text = p.heightCm?.toString() ?? '';
    _locationController.text = p.location ?? '';
    _stakeWardController.text = p.stakeWard ?? '';
    _missionServedController.text = p.missionServed ?? '';
    _missionYearsController.text = p.missionYears ?? '';
    _favoriteCallingController.text = p.favoriteCalling ?? '';
    _favoriteScriptureController.text = p.favoriteScripture ?? '';
    _bioController.text = p.bio ?? '';
    _educationController.text = p.education ?? '';
    _occupationController.text = p.occupation ?? '';

    _selectedInterests = List.from(p.interests);
    _selectedGender = p.gender;
    _selectedMaritalStatus = p.maritalStatus;
    _hasChildren = p.hasChildren ?? false;
    _selectedTempleRecommend = p.templeRecommend;
    _selectedActivityLevel = p.activityLevel;
    _selectedBodyType = p.bodyType;

    _selectedBirthdate = p.birthdate;
    _calculatedAge = p.ageFromBirthdate;

    _profilePhotoPath = p.profilePhotoUrl;
    _profilePhotoKey = p.profilePhotoKey;

    // Inicializar items de galería con keys y URLs firmadas del backend (PASO 5)
    final keys = p.galleryPhotoKeys;
    final urls = p.photoUrls;
    _galleryItems = [];
    for (int i = 0; i < keys.length; i++) {
      final key = keys[i];
      String? url;
      if (i < urls.length) url = urls[i];
      _galleryItems.add(GalleryItem(key: key, url: url));
    }

    _latitude = p.latitude;
    _longitude = p.longitude;

    _hydrated = true;

    // Cargar URLs para las keys de galería en batch
    if (_galleryItems.isNotEmpty) {
      _fetchGalleryUrls();
    }
  }

  Future<void> _fetchGalleryUrls() async {
    final keys =
        _galleryItems.where((i) => i.isRemote).map((i) => i.key!).toList();
    if (keys.isEmpty) return;

    final urlMap = await UsersApi.fetchSignedUrlsBatch(keys);
    if (!mounted) return;

    setState(() {
      _galleryItems = _galleryItems.map((item) {
        if (item.isRemote && urlMap.containsKey(item.key)) {
          return item.copyWith(url: urlMap[item.key]);
        }
        return item;
      }).toList();
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
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
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _gettingLocation = true;
      _locationError = null;
    });

    try {
      // 1. Check Service
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Ubicación desactivada. Por favor actívala.';
      }

      // 2. Check Permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Permisos denegados. No podemos detectar tu ciudad.';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Permisos denegados permanentemente.';
      }

      // 3. Get Position with TimeLimit
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _latitude = position.latitude;
      _longitude = position.longitude;

      // 4. Reverse Geocoding
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final city = place.locality ?? place.subAdministrativeArea ?? '';
        final region = place.administrativeArea ?? '';
        final country = place.country ?? '';

        // Flexible Format: City, Region (if exists) OR City, Country
        String formattedLocation = city;
        if (region.isNotEmpty) {
          formattedLocation += ', $region';
        } else if (country.isNotEmpty) {
          formattedLocation += ', $country';
        }

        setState(() {
          _locationController.text = formattedLocation;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ubicación detectada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = e.toString();
        });

        if (e.toString().contains('permanentemente')) {
          _showPermissionDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _gettingLocation = false);
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permisos de Ubicación'),
        content: const Text(
            'Necesitamos acceso a tu ubicación para sugerirte personas cerca. Por favor habilítalo en la configuración de tu teléfono.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Geolocator.openAppSettings();
              },
              child: const Text('Abrir Configuración')),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);

    final String fName = _firstNameController.text.trim();
    final String lName = _lastNameController.text.trim();
    final String combined = '$fName $lName';

    final String cleanedName = combined
        .replaceAll(RegExp(r'\bnull\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'[,\\.\\s]+$'), '')
        .replaceAll(RegExp(r'^[,\\.\\s]+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final updatedProfile = UserProfile(
      name: cleanedName.isEmpty ? null : cleanedName,
      birthdate: _selectedBirthdate,
      age: _calculatedAge,
      gender: _selectedGender,
      heightCm: int.tryParse(_heightController.text),
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
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
      maritalStatus: _selectedMaritalStatus,
      hasChildren: _hasChildren,
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
      interests: _selectedInterests,
      profilePhotoUrl: _profilePhotoPath,
      profilePhotoKey: _profilePhotoKey,
      galleryPhotoKeys:
          _galleryItems.where((i) => i.isRemote).map((i) => i.key!).toList(),
    );

    try {
      await ref.read(profileProvider.notifier).updateProfile(updatedProfile);

      if (!mounted) return;

      setState(() => _saving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Perfil guardado y sincronizado exitosamente')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickProfilePhoto() async {
    final photoPath = await ImagePickerHelper.pickImage(context);
    if (photoPath != null) {
      // PROMPT 2 - Upload inmediato
      setState(() => _saving = true);
      try {
        final newKey =
            await UsersApi.uploadAndSaveProfilePhoto(File(photoPath));
        if (newKey.isNotEmpty) {
          // Refrescar estado global
          ref.read(profileProvider.notifier).loadProfile();
          setState(() {
            _profilePhotoKey = newKey;
            _profilePhotoPath =
                photoPath; // Local path for immediate visual feedback
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Foto actualizada correctamente')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error al subir imagen: $e'),
                backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
  }

  Future<void> _pickAdditionalPhoto() async {
    if (_galleryItems.length >= 6) {
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
      // PROMPT 1 & 4 - Append local item first for immediate feedback
      final localFile = File(photoPath);
      final localItem = GalleryItem(file: localFile);

      setState(() {
        _galleryItems.add(localItem);
        _isUploadingGallery = true;
      });

      try {
        final success = await UsersApi.uploadAndAddGalleryPhoto(localFile);
        if (success) {
          // Obtener el perfil actualizado para tener la nueva key
          final updatedProfile = await UsersApi.getProfile();
          if (updatedProfile != null && mounted) {
            // Reemplazar el item local por el remoto con su key
            final newKey = updatedProfile.galleryPhotoKeys.last;

            // Actualizar provider global silenciosamente
            ref.read(profileProvider.notifier).loadProfile();

            setState(() {
              final index = _galleryItems.indexOf(localItem);
              if (index != -1) {
                _galleryItems[index] = GalleryItem(key: newKey);
              }
              _isUploadingGallery = false;
            });

            // Cargar la signed URL del nuevo item
            _fetchGalleryUrls();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Foto añadida a la galería')),
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _galleryItems.remove(localItem);
            _isUploadingGallery = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error al subir imagen: $e'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _removeAdditionalPhoto(int index) async {
    final item = _galleryItems[index];
    if (item.isLocal) {
      setState(() => _galleryItems.removeAt(index));
      return;
    }

    setState(() => _saving = true);
    try {
      final success = await UsersApi.removeGalleryPhoto(item.key!);
      if (success) {
        // Actualizar provider global
        ref.read(profileProvider.notifier).loadProfile();

        setState(() {
          _galleryItems.removeAt(index);
          _saving = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto eliminada')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al eliminar imagen: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine location icon color/status
    Color locationIconColor = Colors.grey;
    IconData locationIcon = Icons.location_on_outlined;

    if (_gettingLocation) {
      locationIconColor = Colors.blue;
      locationIcon = Icons.autorenew;
    } else if (_latitude != null && _longitude != null) {
      locationIconColor = Colors.green;
      locationIcon = Icons.check_circle;
    } else if (_locationError != null) {
      locationIconColor = Colors.red;
      locationIcon = Icons.error_outline;
    }

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
                  GestureDetector(
                    onTap: _pickProfilePhoto,
                    child: ProfileImage(
                      photoPath:
                          _profilePhotoPath, // Local path for immediate preview
                      photoKey:
                          _profilePhotoKey, // Usar la key del estado local
                      radius: 70,
                    ),
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
              itemCount:
                  _galleryItems.length < 6 ? _galleryItems.length + 1 : 6,
              itemBuilder: (context, index) {
                if (index < _galleryItems.length) {
                  final item = _galleryItems[index];

                  // UI para Foto Local Nueva
                  if (item.isLocal) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            item.file!,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        if (_isUploadingGallery)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black26,
                              child: const Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeAdditionalPhoto(index),
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: theme.colorScheme.error,
                              child: const Icon(Icons.close,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  // UI para Foto Remota Existente
                  return PhotoPickerWidget(
                    photoKey: item.key,
                    authenticatedUrl:
                        item.url, // Pasar la URL firmada ya cargada
                    onTap: () {},
                    onRemove: () => _removeAdditionalPhoto(index),
                    size: 100,
                  );
                } else {
                  return PhotoPickerWidget(
                    photoPath: null,
                    onTap: _isUploadingGallery
                        ? () {}
                        : () => _pickAdditionalPhoto(),
                    size: 100,
                  );
                }
              },
            ),

            const SizedBox(height: 32),

            // Basic Information Section
            _buildSectionHeader('Información básica', Icons.person),
            const SizedBox(height: 16),

            // Row: Nombre + Apellido
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Requerido';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Apellido',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Requerido';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Row 1: Age + Gender
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedBirthdate ??
                            now.subtract(const Duration(days: 365 * 25)),
                        firstDate: DateTime(now.year - 100),
                        lastDate: DateTime(now.year - 18),
                        helpText: 'Selecciona tu fecha de nacimiento',
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedBirthdate = picked;
                          // Recalcular edad
                          final tempProfile = UserProfile(birthdate: picked);
                          _calculatedAge = tempProfile.ageFromBirthdate;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Edad (calculada)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.cake),
                      ),
                      child: Text(
                        _calculatedAge?.toString() ?? 'Set birthdate',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
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
                    onChanged: (value) =>
                        setState(() => _selectedGender = value),
                    validator: (value) => value == null ? 'Requerido' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Row 2: Marital Status
            DropdownButtonFormField<MaritalStatus>(
              initialValue: _selectedMaritalStatus,
              decoration: const InputDecoration(
                labelText: 'Estado Civil',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.favorite_border),
              ),
              items: MaritalStatus.values.map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(status.displayName),
                );
              }).toList(),
              onChanged: (value) =>
                  setState(() => _selectedMaritalStatus = value),
            ),
            const SizedBox(height: 16),

            // Row 3: Height + Has Children
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _heightController,
                    decoration: const InputDecoration(
                      labelText: 'Altura (cm)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.height),
                      helperText: 'Ej. 170',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final height = int.tryParse(value);
                        if (height == null || height < 100 || height > 250) {
                          return 'Inválida';
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: SwitchListTile(
                    title: const Text('¿Hijos?'),
                    subtitle: Text(_hasChildren ? 'Sí' : 'No'),
                    value: _hasChildren,
                    onChanged: (bool value) {
                      setState(() => _hasChildren = value);
                    },
                    secondary: const Icon(Icons.child_care),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Complexión
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

            // --- Location Section (Updated) ---
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Ubicación *',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(locationIcon, color: locationIconColor),
                // Remove suffix icon to use dedicated button
                helperText:
                    _locationError ?? 'Ciudad, Región o País (Manual o GPS)',
                helperStyle: _locationError != null
                    ? const TextStyle(color: Colors.red)
                    : null,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'La ubicación es requerida';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _gettingLocation ? null : _getCurrentLocation,
                icon: _gettingLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location),
                label: Text(_gettingLocation
                    ? 'Detectando...'
                    : 'Detectar mi ubicación'),
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

            // Save Button
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
