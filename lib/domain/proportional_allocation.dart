import 'models.dart';

/// Distributes stock in 0.1 kg units, without exceeding any school's request.
List<Allocation> distributeProportionally(
  double availableKg,
  List<SchoolRequest> requests,
) {
  if (!availableKg.isFinite || availableKg < 0) {
    throw ArgumentError.value(availableKg, 'availableKg');
  }
  if (requests.any(
    (request) => !request.requestedKg.isFinite || request.requestedKg < 0,
  )) {
    throw ArgumentError('Requests must contain nonnegative finite quantities.');
  }
  if (requests.isEmpty) return const [];

  final capacities = requests
      .map((request) => (request.requestedKg * 10 + 1e-9).floor())
      .toList();
  final totalRequested = capacities.fold<int>(0, (sum, value) => sum + value);
  final availableUnits = (availableKg * 10 + 1e-9).floor();
  final target =
      availableUnits < totalRequested ? availableUnits : totalRequested;
  if (totalRequested == 0) {
    return [
      for (final request in requests)
        Allocation(
          school: request.school,
          requestedKg: request.requestedKg,
          allocatedKg: 0,
        ),
    ];
  }

  final shares =
      capacities.map((capacity) => capacity * target / totalRequested).toList();
  final units = shares.map((share) => share.floor()).toList();
  var remainder = target - units.fold<int>(0, (sum, value) => sum + value);
  final order = List<int>.generate(requests.length, (index) => index)
    ..sort((a, b) {
      final comparison = (shares[b] - units[b]).compareTo(shares[a] - units[a]);
      return comparison == 0 ? a.compareTo(b) : comparison;
    });
  for (final index in order) {
    if (remainder == 0) break;
    if (units[index] < capacities[index]) {
      units[index]++;
      remainder--;
    }
  }
  return [
    for (var index = 0; index < requests.length; index++)
      Allocation(
        school: requests[index].school,
        requestedKg: requests[index].requestedKg,
        allocatedKg: units[index] / 10,
      ),
  ];
}
