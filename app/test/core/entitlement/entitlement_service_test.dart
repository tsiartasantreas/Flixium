import 'package:flutter_test/flutter_test.dart';
import 'package:iflixify/core/entitlement/entitlement_service.dart';

void main() {
  group('EntitlementService', () {
    late EntitlementService service;

    setUp(() {
      service = EntitlementService();
    });

    group('default state (no user)', () {
      test('getTier returns "free" when no user is signed in', () async {
        final tier = await service.getTier();
        expect(tier, 'free');
      });

      test('isPro returns false when tier is "free"', () {
        expect(service.isPro, isFalse);
      });

      test('isAnonymous returns true when no user is signed in', () {
        // Without a real Supabase client, currentUser is null.
        expect(service.isAnonymous, isTrue);
      });

      test('isAdmin returns false by default', () {
        expect(service.isAdmin, isFalse);
      });

      test('service can be instantiated', () {
        expect(service, isA<EntitlementService>());
      });
    });

    group('refreshTier', () {
      test('resets to "free" when no user is signed in', () async {
        await service.refreshTier();
        expect(await service.getTier(), 'free');
        expect(service.isPro, isFalse);
        expect(service.isAdmin, isFalse);
      });
    });
  });
}
