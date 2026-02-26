import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'profile_preview_screen.dart';
import '../data/user_profile.dart';
import '../features/profile/presentation/providers/profile_provider.dart';
import 'compat_quiz_screen.dart';
import 'compat_summary_screen.dart';
import 'profile_edit_screen.dart';
import 'verify_profile_screen.dart';

import '../services/api_client.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/starry_background.dart';
import '../widgets/voice_intro_widget.dart';
import 'package:celestya/screens/image_viewer_screen.dart';
import '../widgets/profile_image.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[ProfileScreen] App resumed, refreshing...');
      ref.read(profileProvider.notifier).loadProfile();
    }
  }

  /// Normaliza strings para evitar mostrar "null", "undefined", espacios, etc.
  String? _cleanString(String? v) {
    if (v == null) return null;
    final s = v.trim();
    if (s.isEmpty) return null;
    final low = s.toLowerCase();
    if (low == 'null' || low == 'undefined' || low == 'none') return null;
    return s;
  }

  Future<bool> _checkQuizStatus() async {
    return false;
  }

  Future<void> _openEditProfile(
      BuildContext context, UserProfile? profile) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ProfileEditScreen(profile: profile ?? UserProfile.empty()),
      ),
    );

    if (result == true) {
      ref.read(profileProvider.notifier).loadProfile();
    }
  }

  Future<void> _openQuiz(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CompatQuizScreen(),
      ),
    );
    ref.read(profileProvider.notifier).loadProfile();
    ref.refresh(quizStatusProvider);
  }

  void _openSummary(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CompatSummaryScreen(),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.logoutConfirmTitle),
        content: Text(loc.logoutConfirmDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: Text(loc.logout),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/auth_gate',
          (route) => false,
        );
      }
    }
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.deleteAccountTitle),
        content: Text(loc.deleteAccountDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: Text(loc.deleteAccountBtn),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiClient.deleteMyAccount();
        await ref.read(authProvider.notifier).logout();
        if (context.mounted) {
          final loc = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.deleteAccountSuccess)),
          );
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/auth_gate',
            (route) => false,
          );
        }
      } catch (e) {
        if (context.mounted) {
          final loc = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${loc.deleteAccountError}: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showLanguagePicker(
      BuildContext context, WidgetRef ref, AppLocalizations loc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: CelestyaColors.deepNight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  loc.language,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                title: Text(loc.spanish,
                    style: const TextStyle(color: Colors.white)),
                onTap: () {
                  ref.read(languageProvider.notifier).setLocale('es');
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(loc.savedToast)),
                  );
                },
              ),
              ListTile(
                title: Text(loc.english,
                    style: const TextStyle(color: Colors.white)),
                onTap: () {
                  ref.read(languageProvider.notifier).setLocale('en');
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(loc.savedToast)),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(profileProvider);
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.language),
          onPressed: () => _showLanguagePicker(context, ref, loc),
        ),
        title: Text(loc.profile, style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility_rounded, size: 20),
            tooltip: 'Vista Previa como Match',
            onPressed: () {
              final profile = profileAsync.valueOrNull;
              if (profile != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => ProfilePreviewScreen(profile: profile),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: CelestyaColors.vibrantCelestialGradient,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 600,
            child: StarryBackground(
              numberOfStars: 150,
              baseColor: const Color(0xFFE0E0E0),
            ),
          ),
          SafeArea(
            child: profileAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(
                      loc.errorLoadingProfile,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.refresh(profileProvider),
                      child: Text(loc.retry),
                    ),
                  ],
                ),
              ),
              data: (profile) {
                final cleanedName = _cleanString(profile.name);
                final hasProfile = cleanedName != null;

                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(profileProvider.notifier).loadProfile(),
                  color: CelestyaColors.starlightGold,
                  backgroundColor: CelestyaColors.mysticalPurple,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildProfileHeader(context, profile, hasProfile),
                        const SizedBox(height: 24),
                        if (profile.photoUrls.isNotEmpty) ...[
                          _buildPhotoGallery(context, profile),
                          const SizedBox(height: 24),
                        ],
                        _buildVerificationCard(context, profile),
                        const SizedBox(height: 24),
                        if (hasProfile) ...[
                          _buildCompletionIndicator(context, profile),
                          const SizedBox(height: 24),
                        ],
                        if (hasProfile) ...[
                          VoiceIntroWidget(profile: profile, ref: ref),
                          const SizedBox(height: 24),
                        ],
                        if (hasProfile) ...[
                          _buildLDSInfoCard(context, profile),
                          const SizedBox(height: 24),
                        ],
                        if (_cleanString(profile.bio) != null) ...[
                          _buildAboutMeSection(context, profile),
                          const SizedBox(height: 24),
                        ],
                        if (hasProfile) ...[
                          _buildDetailsSection(context, profile),
                          const SizedBox(height: 24),
                        ],
                        if (profile.interests.isNotEmpty) ...[
                          _buildInterestsSection(context, profile),
                          const SizedBox(height: 24),
                        ],
                        _buildCompatibilitySection(context),
                        const SizedBox(height: 24),
                        if (!hasProfile) ...[
                          _buildEmptyState(context),
                        ],
                        const SizedBox(height: 32),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFE4E1).withOpacity(0.3),
                                blurRadius: 15,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: OutlinedButton.icon(
                            onPressed: () => _confirmLogout(context),
                            icon: const Icon(Icons.logout),
                            label: Text(loc.logout),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFFE4E1),
                              side: BorderSide(
                                  color:
                                      const Color(0xFFFFE4E1).withOpacity(0.8)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: () => _confirmDeleteAccount(context),
                          icon: const Icon(Icons.delete_forever, size: 20),
                          label: Text(loc.deleteAccount),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Celestial Profile Components ---

  Widget _buildProfileHeader(
      BuildContext context, UserProfile profile, bool hasProfile) {
    final loc = AppLocalizations.of(context)!;
    final displayName =
        hasProfile ? formatDisplayName(profile) : loc.completeYourProfile;

    final initials = (hasProfile && displayName.isNotEmpty)
        ? displayName.substring(0, 1).toUpperCase()
        : 'C';

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            _openEditProfile(context, profile);
          },
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      CelestyaColors.mysticalPurple,
                      CelestyaColors.celestialBlue,
                      CelestyaColors.nebulaPink,
                      Color(0xFF8A2BE2),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: CelestyaColors.mysticalPurple.withOpacity(0.5),
                      blurRadius: 25,
                      spreadRadius: 3,
                    ),
                    BoxShadow(
                      color: CelestyaColors.celestialBlue.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 1,
                      offset: const Offset(-2, -2),
                    ),
                  ],
                ),
                child: ProfileImage(
                  photoKey: profile.profilePhotoKey,
                  photoPath: profile.profilePhotoUrl,
                  radius: 60,
                  placeholder: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: CelestyaColors.starlightGold,
                    ),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: CelestyaColors.celestialBlue,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.edit, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      loc.edit,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                displayName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (profile.verificationStatus == 'approved') ...[
              const SizedBox(width: 6),
              const Icon(Icons.verified_rounded,
                  color: CelestyaColors.auroraTeal, size: 24),
            ],
            const SizedBox(width: 8),
            if (hasProfile)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: CelestyaColors.auroraTeal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: CelestyaColors.auroraTeal.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_rounded,
                        size: 14, color: CelestyaColors.auroraTeal),
                    const SizedBox(width: 4),
                    Text(
                      loc.trusted,
                      style: const TextStyle(
                        color: CelestyaColors.auroraTeal,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (profile.location != null && profile.location!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on_outlined,
                  size: 16, color: Colors.white.withOpacity(0.7)),
              const SizedBox(width: 4),
              Text(
                '${profile.location}${profile.age != null ? ', ${profile.age} años' : ''}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCompletionIndicator(BuildContext context, UserProfile profile) {
    final loc = AppLocalizations.of(context)!;
    final percentage = profile.completionPercentage;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CelestyaColors.deepNight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.yourProgress,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loc.completeProfileHint,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 45,
                    height: 45,
                    child: CircularProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation(
                          CelestyaColors.starlightGold),
                      strokeWidth: 4,
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: const TextStyle(
                      color: CelestyaColors.starlightGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompatibilitySection(BuildContext context) {
    final quizStatusAsync = ref.watch(quizStatusProvider);
    final quizCompleted = quizStatusAsync.value ?? false;
    final loc = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CelestyaColors.deepNight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  color: CelestyaColors.starlightGold, size: 20),
              const SizedBox(width: 8),
              Text(
                loc.compatQuiz,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            quizCompleted ? loc.quizCompletedDesc : loc.quizPendingDesc,
            style:
                TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: quizCompleted
                  ? []
                  : [
                      BoxShadow(
                        color: CelestyaColors.mysticalPurple.withOpacity(0.4),
                        blurRadius: 15,
                        spreadRadius: 1,
                      ),
                    ],
            ),
            child: OutlinedButton(
              onPressed: quizCompleted ? null : () => _openQuiz(context),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    quizCompleted ? Colors.white38 : const Color(0xFFFFF8E7),
                side: BorderSide(
                    color: quizCompleted
                        ? Colors.white12
                        : const Color(0xFFFFF8E7),
                    width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                backgroundColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                quizCompleted ? loc.quizCompletedBtn : loc.takeQuizBtn,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.person_add,
              size: 64,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              loc.completeYourProfile,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loc.emptyProfileDesc,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                final profile = ref.read(profileProvider).valueOrNull;
                _openEditProfile(context, profile);
              },
              icon: const Icon(Icons.edit),
              label: Text(loc.editProfileBtn),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationCard(BuildContext context, UserProfile profile) {
    final status = profile.verificationStatus ?? 'none';
    final loc = AppLocalizations.of(context)!;

    Color statusColor;
    String statusText;
    IconData statusIcon;
    Widget? action;

    switch (status) {
      case 'approved':
        statusColor = CelestyaColors.auroraTeal;
        statusText = loc.verified;
        statusIcon = Icons.verified_rounded;
        break;
      case 'pending_review': // Nuevo estado centralizado
        statusColor = CelestyaColors.starlightGold;
        statusText = loc.pendingReview;
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case 'pending_upload': // Nuevo estado centralizado
        statusColor = CelestyaColors.celestialBlue;
        statusText = loc.pendingUpload;
        statusIcon = Icons.add_a_photo_rounded;
        action = TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const VerifyProfileScreen()),
          ),
          child: Text(loc.continueBtn,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        );
        break;
      case 'rejected':
        statusColor = Colors.redAccent;
        statusText = loc.rejected;
        statusIcon = Icons.error_outline_rounded;
        action = TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const VerifyProfileScreen()),
          ),
          child: Text(loc.retry,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        );
        break;
      default:
        statusColor = Colors.white54;
        statusText = loc.unverified;
        statusIcon = Icons.no_accounts_rounded;
        action = TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const VerifyProfileScreen()),
          ),
          child: Text(loc.verifyNow,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CelestyaColors.deepNight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (status == 'none' || status == 'pending_upload')
                      Text(
                        status == 'pending_upload'
                            ? (profile.activeInstruction ??
                                'Sube tu selfie para completar')
                            : loc.getTrustedSeal,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                      ),
                    if (status == 'rejected' && profile.rejectionReason != null)
                      Text(
                        profile.rejectionReason!,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                  ],
                ),
              ),
              if (action != null) action,
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGallery(BuildContext context, UserProfile profile) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final photoKeys = profile.galleryPhotoKeys;
    final photoUrls = profile.photoUrls;

    if (photoKeys.isEmpty && photoUrls.isEmpty) return const SizedBox.shrink();

    final displayPhotos = photoUrls.isNotEmpty ? photoUrls : photoKeys;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.photo_library, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  loc.myPhotos,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: displayPhotos.length,
              itemBuilder: (context, index) {
                final photo = displayPhotos[index];
                final bool isDirectUrl = photo.startsWith('http');

                return GestureDetector(
                  onTap: () =>
                      ImageViewerScreen.open(context, displayPhotos, index),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: isDirectUrl
                        ? Image.network(
                            photo,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.broken_image, size: 20),
                            ),
                          )
                        : ProfileImage(
                            photoKey: photo,
                            radius: 50,
                          ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLDSInfoCard(BuildContext context, UserProfile profile) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.church, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  loc.ldsInfo,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (profile.stakeWard != null)
              _buildInlineInfoRow(context, Icons.location_city, loc.stakeWard,
                  profile.stakeWard!),
            if (profile.missionServed != null) ...[
              const SizedBox(height: 12),
              _buildInlineInfoRow(context, Icons.flight_takeoff, loc.mission,
                  profile.missionServed!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInlineInfoRow(
      BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon,
            size: 20, color: theme.colorScheme.onSurface.withOpacity(0.6)),
        const SizedBox(width: 8),
        Text('$label: ',
            style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.w500)),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _buildAboutMeSection(BuildContext context, UserProfile profile) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.aboutMe,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(profile.bio ?? '', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSection(BuildContext context, UserProfile profile) {
    final loc = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.details,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (profile.heightCm != null)
              _buildInfoRow(
                  context, Icons.height, loc.height, profile.heightDisplay),
            if (profile.maritalStatus != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(context, Icons.favorite, loc.maritalStatus,
                  profile.maritalStatus!.displayName),
            ],
            if (profile.education != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                  context, Icons.school, loc.education, profile.education!),
            ],
            if (profile.occupation != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                  context, Icons.work, loc.occupation, profile.occupation!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInterestsSection(BuildContext context, UserProfile profile) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.interests,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: profile.interests
                  .map((i) => Chip(
                      label: Text(
                        i,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: theme.colorScheme.primaryContainer))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
