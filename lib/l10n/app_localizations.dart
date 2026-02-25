import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es')
  ];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'Celestya'**
  String get appTitle;

  /// No description provided for @email.
  ///
  /// In es, this message translates to:
  /// **'Correo'**
  String get email;

  /// No description provided for @password.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get password;

  /// No description provided for @login.
  ///
  /// In es, this message translates to:
  /// **'Iniciar Sesión'**
  String get login;

  /// No description provided for @register.
  ///
  /// In es, this message translates to:
  /// **'Registrar'**
  String get register;

  /// No description provided for @profile.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get profile;

  /// No description provided for @language.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get language;

  /// No description provided for @spanish.
  ///
  /// In es, this message translates to:
  /// **'Español'**
  String get spanish;

  /// No description provided for @english.
  ///
  /// In es, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @savedToast.
  ///
  /// In es, this message translates to:
  /// **'Guardado'**
  String get savedToast;

  /// No description provided for @verified.
  ///
  /// In es, this message translates to:
  /// **'Verificado'**
  String get verified;

  /// No description provided for @pendingUpload.
  ///
  /// In es, this message translates to:
  /// **'Subida Pendiente'**
  String get pendingUpload;

  /// No description provided for @pendingReview.
  ///
  /// In es, this message translates to:
  /// **'Revisión Pendiente'**
  String get pendingReview;

  /// No description provided for @rejected.
  ///
  /// In es, this message translates to:
  /// **'Rechazado'**
  String get rejected;

  /// No description provided for @networkError.
  ///
  /// In es, this message translates to:
  /// **'Error de Red'**
  String get networkError;

  /// No description provided for @retry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;

  /// No description provided for @edit.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get edit;

  /// No description provided for @trusted.
  ///
  /// In es, this message translates to:
  /// **'Confiable'**
  String get trusted;

  /// No description provided for @yourProgress.
  ///
  /// In es, this message translates to:
  /// **'Tu progreso'**
  String get yourProgress;

  /// No description provided for @completeProfileHint.
  ///
  /// In es, this message translates to:
  /// **'Un perfil completo atrae conexiones más profundas'**
  String get completeProfileHint;

  /// No description provided for @compatQuiz.
  ///
  /// In es, this message translates to:
  /// **'Cuestionario de compatibilidad'**
  String get compatQuiz;

  /// No description provided for @quizCompletedDesc.
  ///
  /// In es, this message translates to:
  /// **'¡Ya completaste tu cuestionario! Tus respuestas nos ayudan a encontrar mejores conexiones.'**
  String get quizCompletedDesc;

  /// No description provided for @quizPendingDesc.
  ///
  /// In es, this message translates to:
  /// **'Aún no has contestado tu cuestionario. Te haremos 12 preguntas para conocer mejor tus preferencias.'**
  String get quizPendingDesc;

  /// No description provided for @quizCompletedBtn.
  ///
  /// In es, this message translates to:
  /// **'Cuestionario completado'**
  String get quizCompletedBtn;

  /// No description provided for @takeQuizBtn.
  ///
  /// In es, this message translates to:
  /// **'Responder cuestionario'**
  String get takeQuizBtn;

  /// No description provided for @completeYourProfile.
  ///
  /// In es, this message translates to:
  /// **'Completa tu perfil'**
  String get completeYourProfile;

  /// No description provided for @emptyProfileDesc.
  ///
  /// In es, this message translates to:
  /// **'Agrega tu información personal, detalles LDS, y fotos para comenzar a conectar con personas afines.'**
  String get emptyProfileDesc;

  /// No description provided for @editProfileBtn.
  ///
  /// In es, this message translates to:
  /// **'Editar perfil'**
  String get editProfileBtn;

  /// No description provided for @unverified.
  ///
  /// In es, this message translates to:
  /// **'Sin verificar'**
  String get unverified;

  /// No description provided for @getTrustedSeal.
  ///
  /// In es, this message translates to:
  /// **'Obtén tu sello de confianza'**
  String get getTrustedSeal;

  /// No description provided for @verifyNow.
  ///
  /// In es, this message translates to:
  /// **'Verificar ahora'**
  String get verifyNow;

  /// No description provided for @continueBtn.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get continueBtn;

  /// No description provided for @myPhotos.
  ///
  /// In es, this message translates to:
  /// **'Mis fotos'**
  String get myPhotos;

  /// No description provided for @ldsInfo.
  ///
  /// In es, this message translates to:
  /// **'Información LDS'**
  String get ldsInfo;

  /// No description provided for @stakeWard.
  ///
  /// In es, this message translates to:
  /// **'Estaca/Barrio'**
  String get stakeWard;

  /// No description provided for @mission.
  ///
  /// In es, this message translates to:
  /// **'Misión'**
  String get mission;

  /// No description provided for @aboutMe.
  ///
  /// In es, this message translates to:
  /// **'Sobre mí'**
  String get aboutMe;

  /// No description provided for @details.
  ///
  /// In es, this message translates to:
  /// **'Detalles'**
  String get details;

  /// No description provided for @height.
  ///
  /// In es, this message translates to:
  /// **'Altura'**
  String get height;

  /// No description provided for @maritalStatus.
  ///
  /// In es, this message translates to:
  /// **'Estado Civil'**
  String get maritalStatus;

  /// No description provided for @education.
  ///
  /// In es, this message translates to:
  /// **'Educación'**
  String get education;

  /// No description provided for @occupation.
  ///
  /// In es, this message translates to:
  /// **'Ocupación'**
  String get occupation;

  /// No description provided for @interests.
  ///
  /// In es, this message translates to:
  /// **'Intereses'**
  String get interests;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Cerrar sesión?'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmDesc.
  ///
  /// In es, this message translates to:
  /// **'Tendrás que ingresar tus credenciales nuevamente para entrar.'**
  String get logoutConfirmDesc;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @logout.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get logout;

  /// No description provided for @deleteAccount.
  ///
  /// In es, this message translates to:
  /// **'Eliminar mi cuenta'**
  String get deleteAccount;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar cuenta?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountDesc.
  ///
  /// In es, this message translates to:
  /// **'Esta acción es irreversible. Se eliminarán todos tus datos, matches y fotos de nuestros servidores.'**
  String get deleteAccountDesc;

  /// No description provided for @deleteAccountBtn.
  ///
  /// In es, this message translates to:
  /// **'ELIMINAR MI CUENTA'**
  String get deleteAccountBtn;

  /// No description provided for @deleteAccountSuccess.
  ///
  /// In es, this message translates to:
  /// **'Cuenta eliminada correctamente'**
  String get deleteAccountSuccess;

  /// No description provided for @deleteAccountError.
  ///
  /// In es, this message translates to:
  /// **'Error al eliminar cuenta'**
  String get deleteAccountError;

  /// No description provided for @errorLoadingProfile.
  ///
  /// In es, this message translates to:
  /// **'Error al cargar perfil'**
  String get errorLoadingProfile;

  /// No description provided for @tabDiscover.
  ///
  /// In es, this message translates to:
  /// **'Descubrir'**
  String get tabDiscover;

  /// No description provided for @tabMatches.
  ///
  /// In es, this message translates to:
  /// **'Matches'**
  String get tabMatches;

  /// No description provided for @tabChats.
  ///
  /// In es, this message translates to:
  /// **'Chats'**
  String get tabChats;

  /// No description provided for @tabProfile.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get tabProfile;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
