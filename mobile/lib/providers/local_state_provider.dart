import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_state_service.dart';

final localStateServiceProvider = Provider<LocalStateService>((ref) {
  return LocalStateService();
});

// Provider per i waypoint scansionati di un tour specifico
final scannedWaypointsProvider = FutureProvider.family<List<int>, int>((
  ref,
  tourId,
) async {
  final localStateService = ref.read(localStateServiceProvider);
  return await localStateService.getScannedWaypoints(tourId);
});

// Provider per verificare se un waypoint è stato scansionato
final isWaypointScannedProvider = FutureProvider.family<bool, Map<String, int>>(
  (ref, params) async {
    final localStateService = ref.read(localStateServiceProvider);
    return await localStateService.isWaypointScanned(
      params['tourId']!,
      params['waypointId']!,
    );
  },
);

// Provider per i tour completati
final completedToursProvider = FutureProvider<List<int>>((ref) async {
  final localStateService = ref.read(localStateServiceProvider);
  return await localStateService.getCompletedTours();
});
