import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/language_service.dart';
import '../services/users_api.dart';

// Este provider necesita ser sobrescrito en main.dart despues de inicializar SharedPreferences
final languageServiceProvider = Provider<LanguageService>((ref) {
  throw UnimplementedError('languageServiceProvider not initialized');
});

final languageProvider =
    StateNotifierProvider<LanguageController, Locale>((ref) {
  return LanguageController(ref);
});

class LanguageController extends StateNotifier<Locale> {
  final Ref ref;

  LanguageController(this.ref) : super(const Locale('es')) {
    _initLocale();
  }

  Future<void> _initLocale() async {
    final languageService = ref.read(languageServiceProvider);
    final savedLang = languageService.getSavedLanguage();

    if (savedLang != null) {
      state = Locale(savedLang);
    } else {
      // Fallback a locale del dispositivo
      final deviceLocale = PlatformDispatcher.instance.locale.languageCode;
      if (deviceLocale.startsWith('en')) {
        state = const Locale('en');
      } else if (deviceLocale.startsWith('es')) {
        state = const Locale('es');
      } else {
        state = const Locale('es'); // fallback a es
      }
    }
  }

  /// Override the locale immediately, normally called post-login
  /// if a language property was retrieved from the backend.
  Future<void> syncWithBackend(String? backendLang) async {
    if (backendLang == 'es' || backendLang == 'en') {
      final languageService = ref.read(languageServiceProvider);
      await languageService.saveLanguage(backendLang!);
      state = Locale(backendLang);
    }
  }

  /// Update the locale locally and persist it to SharedPreferences.
  /// Fire-and-forget sync to the backend API.
  Future<void> setLocale(String lang) async {
    if (lang != 'es' && lang != 'en') return;

    state = Locale(lang);

    final languageService = ref.read(languageServiceProvider);
    await languageService.saveLanguage(lang);

    try {
      await UsersApi.setMyLanguage(lang);
    } catch (e) {
      // Puede que no haya sesión o haya error de red, ignore for now
    }
  }
}
