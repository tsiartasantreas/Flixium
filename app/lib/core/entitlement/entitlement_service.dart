/// Anon entitlement stub for free/pro gating.
///
/// Phase 1: Always returns "free". Phase 3 will connect to Supabase
/// and implement real subscription checks.
class EntitlementService {
  /// Returns the current user tier as a string.
  ///
  /// Always returns `"free"` in Phase 1.
  Future<String> getTier() async => 'free';

  /// Whether the current user has a pro subscription.
  ///
  /// Always returns `false` in Phase 1.
  bool get isPro => false;
}
