import 'package:flutter_test/flutter_test.dart';
import 'package:nativa/domain/models.dart';
import 'package:nativa/domain/proportional_allocation.dart';

void main() {
  group('distributeProportionally', () {
    test('shares limited stock according to requests and conserves total', () {
      final result = distributeProportionally(10, const [
        SchoolRequest(school: 'A', requestedKg: 10),
        SchoolRequest(school: 'B', requestedKg: 20),
        SchoolRequest(school: 'C', requestedKg: 30),
      ]);

      expect(result.map((item) => item.allocatedKg), [1.7, 3.3, 5.0]);
      expect(result.fold<double>(0, (sum, item) => sum + item.allocatedKg), 10);
    });

    test('caps allocation at requested amount when stock is abundant', () {
      final result = distributeProportionally(100, const [
        SchoolRequest(school: 'A', requestedKg: 2),
        SchoolRequest(school: 'B', requestedKg: 3),
      ]);
      expect(result.map((item) => item.allocatedKg), [2, 3]);
    });

    test('handles a 100 kg delivery for 50 schools', () {
      final requests = List.generate(
        50,
        (index) => SchoolRequest(school: 'Escola $index', requestedKg: 4),
      );
      final result = distributeProportionally(100, requests);
      expect(result.length, 50);
      expect(result.every((item) => item.allocatedKg == 2), isTrue);
    });

    test('never exceeds requests with fractional input', () {
      final result = distributeProportionally(1, const [
        SchoolRequest(school: 'A', requestedKg: 0.15),
      ]);
      expect(result.single.allocatedKg, 0.1);
    });

    test('rejects negative or nonfinite quantities', () {
      expect(() => distributeProportionally(-1, const []), throwsArgumentError);
      expect(
        () => distributeProportionally(1, const [
          SchoolRequest(school: 'A', requestedKg: double.infinity),
        ]),
        throwsArgumentError,
      );
    });
  });
}
