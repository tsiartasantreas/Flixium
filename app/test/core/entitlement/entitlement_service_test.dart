import 'package:flutter_test/flutter_test.dart';
import 'package:iflixify/core/entitlement/entitlement_service.dart';

void main() {
  group('EntitlementService', () {
    late EntitlementService service;

    setUp(() {
      service = EntitlementService();
    });

    test('getTier returns "free"', () async {
      final tier = await service.getTier();
      expect(tier, 'free');
    });

    test('isPro returns false', () {
      expect(service.isPro, isFalse);
    });

    test('service can be instantiated', () {
      expect(service, isA<EntitlementService>());
    });
  });
}
