// lib/services/profile_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/user_profile.dart';

/// Service for managing user profile data persistence
class ProfileService {
  static const String _profileKey = 'user_profile';

  /// Save user profile to SharedPreferences
  Future<bool> saveProfile(UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(profile.toJson());
      return await prefs.setString(_profileKey, jsonString);
    } catch (e) {
      // Log error in production
      return false;
    }
  }

  /// Load user profile from SharedPreferences
  Future<UserProfile> loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_profileKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        return UserProfile.empty();
      }

      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return UserProfile.fromJson(jsonMap);
    } catch (e) {
      // Log error in production, return empty profile
      return UserProfile.empty();
    }
  }

  /// Check if a profile exists
  Future<bool> hasProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_profileKey);
      return jsonString != null && jsonString.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Clear profile data (for logout)
  Future<bool> clearProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_profileKey);
    } catch (e) {
      return false;
    }
  }

  /// Update a specific field in the profile
  Future<bool> updateProfile(UserProfile Function(UserProfile) updater) async {
    try {
      final currentProfile = await loadProfile();
      final updatedProfile = updater(currentProfile);
      return await saveProfile(updatedProfile);
    } catch (e) {
      return false;
    }
  }

  /// Get profile completion percentage
  Future<int> getCompletionPercentage() async {
    final profile = await loadProfile();
    return profile.completionPercentage;
  }

  /// Check if profile is valid (has minimum required fields)
  Future<bool> isProfileValid() async {
    final profile = await loadProfile();
    return profile.isValid;
  }
}
