import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/entitlement/entitlement_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// "Activate Pro" upsell screen (Netflix-dark styled).
///
/// Shows the current tier status, the Pro benefits from the feature matrix
/// (unlimited playlists, multi-user profiles, Continue Watching, cross-device
/// sync), and the one-time lifetime price. The "Upgrade" action opens the
/// website where the purchase is completed (placeholder until the Revolut
/// checkout exists in Phase 4); "Restore Purchase" re-fetches the tier from
/// Supabase so a completed purchase activates immediately.
class ActivateProScreen extends StatefulWidget {
  const ActivateProScreen({super.key});

  @override
  State<ActivateProScreen> createState() => _ActivateProScreenState();
}

class _ActivateProScreenState extends State<ActivateProScreen> {
  final EntitlementService _entitlement = EntitlementService();

  /// Website where the Pro purchase is completed.
  static const String _purchaseUrl = 'https://iflixify.wasmer.app';

  /// One-time lifetime price shown on the screen.
  static const String _price = '\$8.99';

  bool _isPro = false;
  bool _isAdmin = false;
  bool _isRestoring = false;

  @override
  void initState() {
    super.initState();
    _loadTier();
  }

  // ---------------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------------

  Future<void> _loadTier() async {
    await _entitlement.refreshTier();
    if (!mounted) return;
    setState(() {
      _isPro = _entitlement.isPro;
      _isAdmin = _entitlement.isAdmin;
    });
  }

  /// Pro features are unlocked for Pro subscribers and admins.
  bool get _proActive => _isPro || _isAdmin;

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Opens the website in an external browser to complete the purchase.
  Future<void> _openCheckout() async {
    final uri = Uri.parse(_purchaseUrl);
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      _showSnackBar('Could not open $_purchaseUrl');
    }
  }

  /// Re-fetches the tier from Supabase so a completed purchase activates.
  Future<void> _restorePurchase() async {
    if (_isRestoring) return;

    if (_entitlement.isAnonymous) {
      _showSnackBar(
        'Sign in to your account first (Settings > Account), then restore.',
      );
      return;
    }

    setState(() => _isRestoring = true);
    try {
      await _entitlement.refreshTier();
      if (!mounted) return;
      setState(() {
        _isPro = _entitlement.isPro;
        _isAdmin = _entitlement.isAdmin;
      });
      _showSnackBar(
        _proActive
            ? 'Pro restored — all features unlocked.'
            : 'No Pro purchase found for this account.',
      );
    } catch (_) {
      if (mounted) {
        _showSnackBar('Could not check your purchase. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.bgSurface,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
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
          'iFlixify Pro',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.horizontalPadding),
        children: [
          // -- Current tier status ------------------------------------------
          _buildTierBanner(),
          const SizedBox(height: 24),

          // -- Headline ------------------------------------------------------
          const Text(
            'iFlixify Pro',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'One purchase. Everything unlocked. Forever.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 24),

          // -- Benefits ------------------------------------------------------
          _buildBenefitsCard(),
          const SizedBox(height: 24),

          // -- Price ---------------------------------------------------------
          _buildPriceCard(),
          const SizedBox(height: 20),

          // -- Upgrade button ------------------------------------------------
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _proActive ? null : _openCheckout,
              icon: const Icon(Icons.workspace_premium, size: 22),
              label: Text(_proActive ? 'Pro is active' : 'Upgrade for $_price'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentPrimary,
                foregroundColor: AppColors.textPrimary,
                disabledBackgroundColor: AppColors.bgSurface,
                disabledForegroundColor: AppColors.textSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // -- Restore purchase button ---------------------------------------
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _isRestoring ? null : _restorePurchase,
              icon: _isRestoring
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accentPrimary,
                      ),
                    )
                  : const Icon(Icons.restore, size: 18),
              label: Text(_isRestoring ? 'Checking...' : 'Restore Purchase'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.bgSurface),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // -- Fine print ----------------------------------------------------
          const Text(
            'Secure one-time payment of $_price via iflixify.wasmer.app. '
            'Pro activates on this device automatically after purchase — '
            'tap "Restore Purchase" if it does not.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tier status banner
  // ---------------------------------------------------------------------------

  Widget _buildTierBanner() {
    final pro = _proActive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: pro
            ? AppColors.accentPrimary.withValues(alpha: 0.15)
            : AppColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: pro
              ? AppColors.accentPrimary.withValues(alpha: 0.4)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Icon(
            pro ? Icons.verified : Icons.info_outline,
            color: pro ? AppColors.accentPrimary : AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pro ? 'Pro active' : "You're on the Free plan",
              style: TextStyle(
                color: pro ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Benefits
  // ---------------------------------------------------------------------------

  Widget _buildBenefitsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildBenefitTile(
            icon: Icons.playlist_play,
            title: 'Unlimited playlists',
            subtitle:
                'Add as many M3U and Xtream playlists as you like '
                '(Free is limited to 1)',
          ),
          _buildBenefitTile(
            icon: Icons.group_outlined,
            title: 'Multi-user profiles',
            subtitle: 'Personal profiles for everyone in your household',
          ),
          _buildBenefitTile(
            icon: Icons.history,
            title: 'Continue Watching / Up Next',
            subtitle: 'Pick up where you left off across the app',
          ),
          _buildBenefitTile(
            icon: Icons.sync,
            title: 'Cross-device sync',
            subtitle:
                'Playlists, favourites and progress synced across up to '
                '5 devices',
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accentPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.accentPrimary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.check_circle,
            color: AppColors.accentPrimary,
            size: 20,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Price card
  // ---------------------------------------------------------------------------

  Widget _buildPriceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.bgSurface),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _price,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'one-time payment · lifetime access',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.workspace_premium,
            color: AppColors.accentPrimary,
            size: 40,
          ),
        ],
      ),
    );
  }
}
