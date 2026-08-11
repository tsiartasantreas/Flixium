import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/profile_manager.dart';
import '../../core/data/database.dart';
import '../../core/data/supabase_client.dart';
import '../../core/entitlement/entitlement_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_screen.dart';
import '../profiles/profile_switcher_screen.dart';

/// Netflix-style settings screen.
///
/// Displays a list of settings grouped into sections: Profile, Playback,
/// Data, and About. Uses the app's dark theme consistently.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.database});

  /// Database instance -- injectable for testing.
  final AppDatabase? database;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppDatabase? _db;
  late final ProfileManager _profileManager;
  late final EntitlementService _entitlementService;

  // Playback settings.
  bool _autoPlay = true;
  String _videoQuality = 'Auto';

  // Profile.
  String _profileName = 'User';
  String _profileEmail = '';
  String _tier = 'Free';

  static const _qualityOptions = ['Auto', '1080p', '720p', '480p', '360p'];

  @override
  void initState() {
    super.initState();
    _db = widget.database;
    _profileManager = ProfileManager(database: _db);
    _entitlementService = EntitlementService();
    _loadSettings();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  Future<void> _loadSettings() async {
    // Load active profile.
    final activeProfile = await _profileManager.getActiveProfile();
    if (!mounted) return;
    if (activeProfile != null) {
      setState(() {
        _profileName = activeProfile.displayName;
      });
    }

    // Load Supabase user email (if signed in).
    if (SupabaseService.isInitialized) {
      final user = SupabaseService.client.auth.currentUser;
      if (user != null) {
        setState(() {
          _profileEmail = user.email ?? '';
        });
      }
    }

    // Load tier.
    final tier = await _entitlementService.getTier();
    if (!mounted) return;
    setState(() {
      _tier = tier == 'pro' ? 'Pro' : 'Free';
    });
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: const Text(
          'Clear Cache',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'This will clear cached images and temporary files. '
          'Your downloaded content and favourites will not be affected.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Clear',
              style: TextStyle(color: AppColors.accentPrimary),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cache cleared'),
          backgroundColor: AppColors.bgSurface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _clearEpgData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: const Text(
          'Clear EPG Data',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'This will remove all downloaded programme guide data. '
          'It will be re-downloaded on next refresh.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(true);
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: AppColors.accentPrimary),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (_db != null) {
        await _db!.delete(_db!.epgProgrammes).go();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('EPG data cleared'),
            backgroundColor: AppColors.bgSurface,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showQualityPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Video Quality',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ..._qualityOptions.map((quality) {
              final isSelected = quality == _videoQuality;
              return ListTile(
                title: Text(
                  quality,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.accentPrimary
                        : AppColors.textPrimary,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: AppColors.accentPrimary)
                    : null,
                onTap: () {
                  setState(() => _videoQuality = quality);
                  Navigator.of(context).pop();
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgElevated,
        title: const Text(
          'Settings',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // -- Profile section ----------------------------------------------
          _buildSectionHeader('Profile'),
          _buildProfileTile(),

          const SizedBox(height: 16),

          // -- Playback section ---------------------------------------------
          _buildSectionHeader('Playback'),
          _buildSwitchTile(
            icon: Icons.play_circle_outline,
            title: 'Auto-play',
            subtitle: 'Automatically play next item',
            value: _autoPlay,
            onChanged: (value) => setState(() => _autoPlay = value),
          ),
          _buildNavigationTile(
            icon: Icons.high_quality,
            title: 'Video Quality',
            subtitle: _videoQuality,
            onTap: _showQualityPicker,
          ),

          const SizedBox(height: 16),

          // -- Data section -------------------------------------------------
          _buildSectionHeader('Data'),
          _buildNavigationTile(
            icon: Icons.delete_outline,
            title: 'Clear Cache',
            subtitle: 'Free up storage space',
            onTap: _clearCache,
          ),
          _buildNavigationTile(
            icon: Icons.tv_off,
            title: 'Clear EPG Data',
            subtitle: 'Remove programme guide data',
            onTap: _clearEpgData,
          ),

          const SizedBox(height: 16),

          // -- About section ------------------------------------------------
          _buildSectionHeader('About'),
          _buildInfoTile(
            icon: Icons.info_outline,
            title: 'Version',
            subtitle: '1.0.0 (build 1)',
          ),
          _buildNavigationTile(
            icon: Icons.description_outlined,
            title: 'Licenses',
            subtitle: 'Open source licenses',
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Flixium IPTV',
              applicationVersion: '1.0.0',
              applicationIcon: const Icon(
                Icons.live_tv,
                color: AppColors.accentPrimary,
                size: 32,
              ),
              applicationLegalese: 'Copyright 2026 Flixium',
            ),
          ),

          const SizedBox(height: 16),

          // -- Account section ----------------------------------------------
          _buildSectionHeader('Account'),
          _buildNavigationTile(
            icon: Icons.person_outline,
            title: 'Sign Out',
            subtitle: 'Sign out of your account',
            onTap: _showSignOutDialog,
            isDestructive: true,
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section header
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.horizontalPadding,
        8,
        AppTheme.horizontalPadding,
        4,
      ),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Profile tile
  // ---------------------------------------------------------------------------

  Widget _buildProfileTile() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.horizontalPadding),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar.
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  color: AppColors.accentPrimary,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),

              // Name, email, and tier.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _profileName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_profileEmail.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _profileEmail,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _tier == 'Pro'
                            ? AppColors.accentPrimary.withValues(alpha: 0.2)
                            : AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _tier,
                        style: TextStyle(
                          color: _tier == 'Pro'
                              ? AppColors.accentPrimary
                              : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Switch Profile button.
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProfileSwitcherScreen(),
                  ),
                );
                // Reload profile data when returning.
                _loadSettings();
              },
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: const Text('Switch Profile'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.bgSurface),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Switch tile
  // ---------------------------------------------------------------------------

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.accentPrimary,
        activeTrackColor: AppColors.accentPrimary.withValues(alpha: 0.3),
        inactiveTrackColor: AppColors.bgSurface,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Navigation tile
  // ---------------------------------------------------------------------------

  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : AppColors.textSecondary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : AppColors.textPrimary,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: AppColors.textSecondary.withValues(alpha: 0.5),
      ),
      onTap: onTap,
    );
  }

  // ---------------------------------------------------------------------------
  // Info tile (non-interactive)
  // ---------------------------------------------------------------------------

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialogs
  // ---------------------------------------------------------------------------


  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: const Text(
          'Sign Out',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              navigator.pop(); // Close the dialog.
              // Only sign out if Supabase is initialized (user is authenticated).
              if (SupabaseService.isInitialized) {
                await AuthService().signOut();
              }
              if (mounted) {
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
